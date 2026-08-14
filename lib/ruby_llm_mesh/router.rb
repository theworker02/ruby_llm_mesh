# frozen_string_literal: true

module RubyLlmMesh
  class Router
    PROVIDER_MAP = {
      openai: Providers::Openai,
      anthropic: Providers::Anthropic,
      local_node: Providers::LocalNode,
      local_mesh: Providers::LocalNode # alias — multi-peer aware via PeerRegistry
    }.freeze

    class << self
      def circuit_breaker
        @circuit_breaker ||= CircuitBreaker.new(
          failure_threshold: RubyLlmMesh.configuration.circuit_failure_threshold,
          reset_timeout: RubyLlmMesh.configuration.circuit_reset_timeout
        )
      end

      def reset_circuit_breaker!
        @circuit_breaker = nil
      end

      def semantic_cache
        Cache::SemanticCache.instance
      end

      def peer_registry
        Mesh::PeerRegistry.instance
      end

      def health_monitor
        Mesh::HealthMonitor.instance
      end
    end

    def initialize(config: RubyLlmMesh.configuration, circuit_breaker: self.class.circuit_breaker,
                   semantic_cache: nil, budget: nil)
      @config = config
      @circuit_breaker = circuit_breaker
      @semantic_cache = semantic_cache
      @budget = budget
    end

    def complete(prompt:, providers: nil, fallback: nil, system: nil, model: nil, **options)
      raise ArgumentError, "prompt is required" if prompt.nil? || prompt.to_s.strip.empty?

      skip_cache = options.delete(:skip_cache)
      cache = resolve_cache
      unless skip_cache
        cached = cache&.lookup(prompt, system: system)
        if cached
          log(:info, "Semantic cache hit")
          return cached
        end
      end

      maybe_refresh_peer_health!

      provider_list = Array(providers || @config.default_providers).map(&:to_sym)
      raise ArgumentError, "providers list cannot be empty" if provider_list.empty?

      use_fallback = fallback.nil? ? @config.fallback : fallback
      errors = {}
      attempted = 0

      provider_list.each_with_index do |provider_name, index|
        circuit_key = circuit_key_for(provider_name)

        unless PROVIDER_MAP.key?(provider_name)
          errors[provider_name] = ProviderError.new("Unknown provider: #{provider_name}", provider: provider_name)
          break unless use_fallback
          next
        end

        unless @circuit_breaker.allow?(circuit_key)
          errors[provider_name] = CircuitOpenError.new(
            "Circuit open for #{provider_name}",
            provider: provider_name
          )
          log(:warn, "Skipping #{provider_name} — circuit open")
          break unless use_fallback
          next
        end

        begin
          attempted += 1
          log(:info, "Routing to #{provider_name}")
          budget = resolve_budget
          estimated_tokens = Budget.estimate_tokens(prompt: prompt, system: system, max_tokens: options[:max_tokens])
          estimated_usd = Budget.estimate_usd(tokens: estimated_tokens, model: model, config: @config)
          budget.check!(estimated_tokens: estimated_tokens, estimated_usd: estimated_usd)

          provider = PROVIDER_MAP[provider_name].new(@config)
          response = with_retries(provider_name) do
            provider.complete(prompt: prompt, system: system, model: model, **options)
          end
          budget.consume!(usage: response.usage, provider: provider_name, model: response.model || model)
          @circuit_breaker.record_success(circuit_key)

          result = Response.new(
            content: response.content,
            provider: response.provider,
            model: response.model,
            usage: response.usage,
            raw: response.raw,
            latency_ms: response.latency_ms,
            fallback_used: index.positive?,
            cache_hit: false
          )
          cache&.store_response(prompt, result, system: system) unless skip_cache
          return result
        rescue BudgetExceededError
          raise
        rescue AuthenticationError => e
          @circuit_breaker.record_failure(circuit_key)
          errors[provider_name] = e
          log(:error, "#{provider_name} authentication failed: #{e.message}")
          break unless use_fallback
        rescue RateLimitError => e
          # Trip circuit immediately so subsequent requests skip this provider
          force_open_circuit!(circuit_key)
          errors[provider_name] = e
          log(:error, "#{provider_name} rate limited: #{e.message}")
          break unless use_fallback
        rescue ProviderError => e
          @circuit_breaker.record_failure(circuit_key)
          errors[provider_name] = e
          log(:error, "#{provider_name} failed: #{e.message}")
          break unless use_fallback
        end
      end

      raise AllProvidersFailedError, errors
    end

    private

    def resolve_cache
      return @semantic_cache if @semantic_cache
      return nil unless @config.semantic_cache_enabled

      Cache::SemanticCache.instance(config: @config)
    end

    def resolve_budget
      return @budget if @budget

      Budget.instance(config: @config)
    end

    def circuit_key_for(provider_name)
      provider_name == :local_mesh ? :local_node : provider_name
    end

    def maybe_refresh_peer_health!
      return unless @config.peer_discovery_enabled

      monitor = Mesh::HealthMonitor.instance(config: @config)
      monitor.start!
      # Opportunistic sync check so first request after enable sees fresh state
      monitor.check_all!
    end

    def force_open_circuit!(circuit_key)
      threshold = @config.circuit_failure_threshold
      threshold.times { @circuit_breaker.record_failure(circuit_key) }
    end

    def with_retries(provider_name)
      attempts = 1 + [Integer(@config.max_retries || 0), 0].max
      last_error = nil

      attempts.times do |index|
        return yield
      rescue AuthenticationError, BudgetExceededError
        raise
      rescue RateLimitError, TimeoutError, ProviderError => error
        last_error = error
        remaining = attempts - index - 1
        unless retryable_error?(error) && remaining.positive?
          raise error
        end

        delay = retry_delay(index)
        log(:warn, "#{provider_name} attempt #{index + 1}/#{attempts} failed (#{error.class}): #{error.message}; retrying in #{delay}s")
        sleep(delay) if delay.positive?
      end

      raise last_error
    end

    def retryable_error?(error)
      return false if error.is_a?(AuthenticationError)
      return true if error.is_a?(TimeoutError) || error.is_a?(RateLimitError)
      return false unless error.is_a?(ProviderError)

      status = error.status
      status.nil? || status >= 500 || status == 429
    end

    def retry_delay(attempt)
      base = Float(@config.retry_backoff || 0)
      base * (2**attempt)
    end

    def log(level, message)
      logger = @config.logger
      return unless logger

      if logger.respond_to?(level)
        logger.public_send(level, "[RubyLlmMesh] #{message}")
      elsif logger.respond_to?(:call)
        logger.call(level, message)
      end
    end
  end
end

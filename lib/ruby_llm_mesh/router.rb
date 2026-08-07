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
                   semantic_cache: nil)
      @config = config
      @circuit_breaker = circuit_breaker
      @semantic_cache = semantic_cache
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
          next
        end

        unless @circuit_breaker.allow?(circuit_key)
          errors[provider_name] = CircuitOpenError.new(
            "Circuit open for #{provider_name}",
            provider: provider_name
          )
          log(:warn, "Skipping #{provider_name} — circuit open")
          next
        end

        begin
          attempted += 1
          log(:info, "Routing to #{provider_name}")
          provider = PROVIDER_MAP[provider_name].new(@config)
          response = provider.complete(prompt: prompt, system: system, model: model, **options)
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

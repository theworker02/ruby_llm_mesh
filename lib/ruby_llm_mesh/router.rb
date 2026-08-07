# frozen_string_literal: true

module RubyLlmMesh
  class Router
    PROVIDER_MAP = {
      openai: Providers::Openai,
      anthropic: Providers::Anthropic,
      local_node: Providers::LocalNode
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
    end

    def initialize(config: RubyLlmMesh.configuration, circuit_breaker: self.class.circuit_breaker)
      @config = config
      @circuit_breaker = circuit_breaker
    end

    def complete(prompt:, providers: nil, fallback: nil, system: nil, model: nil, **options)
      raise ArgumentError, "prompt is required" if prompt.nil? || prompt.to_s.strip.empty?

      provider_list = Array(providers || @config.default_providers).map(&:to_sym)
      raise ArgumentError, "providers list cannot be empty" if provider_list.empty?

      use_fallback = fallback.nil? ? @config.fallback : fallback
      errors = {}
      attempted = 0

      provider_list.each_with_index do |provider_name, index|
        unless PROVIDER_MAP.key?(provider_name)
          errors[provider_name] = ProviderError.new("Unknown provider: #{provider_name}", provider: provider_name)
          next
        end

        unless @circuit_breaker.allow?(provider_name)
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
          @circuit_breaker.record_success(provider_name)
          return Response.new(
            content: response.content,
            provider: response.provider,
            model: response.model,
            usage: response.usage,
            raw: response.raw,
            latency_ms: response.latency_ms,
            fallback_used: index.positive?
          )
        rescue ProviderError => e
          @circuit_breaker.record_failure(provider_name)
          errors[provider_name] = e
          log(:error, "#{provider_name} failed: #{e.message}")
          break unless use_fallback
        end
      end

      raise AllProvidersFailedError, errors
    end

    private

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

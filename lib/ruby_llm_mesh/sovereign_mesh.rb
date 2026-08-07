# frozen_string_literal: true

require "json"

module RubyLlmMesh
  # Sovereign mesh orchestrator — native P2P node + cloud failover strategies.
  class SovereignMesh
    STRATEGIES = %i[auto p2p_mesh cloud openai anthropic local_node local_mesh].freeze

    def initialize(config: RubyLlmMesh.configuration, router: nil)
      @config = config
      @router = router || Router.new(config: config)
    end

    def boot!(port: @config.mesh_port)
      NativeCore.start_node(port)
    end

    def shutdown!
      NativeCore.stop_node
    end

    def alive?
      NativeCore.node_alive?
    end

    # Execute an intent with a routing strategy.
    #
    # Strategies:
    # - +:auto+ — native mesh when alive (or auto-boot), else cloud ladder
    # - +:p2p_mesh+ — native chimera_core only
    # - +:cloud+ — real HTTP via +fallback_providers+ / +default_providers+
    # - +:openai+ / +:anthropic+ / +:local_node+ / +:local_mesh+ — single-provider cloud/local
    def execute(intent:, strategy: :auto, **options)
      raise ArgumentError, "intent is required" if intent.nil? || intent.to_s.strip.empty?

      strategy = strategy.to_sym
      unless STRATEGIES.include?(strategy)
        raise ArgumentError, "Unknown strategy: #{strategy.inspect} (expected one of #{STRATEGIES.join(', ')})"
      end

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = case strategy
               when :p2p_mesh
                 execute_p2p(intent)
               when :cloud
                 execute_cloud(intent, **options)
               when :openai, :anthropic, :local_node, :local_mesh
                 execute_cloud(intent, providers: [strategy], **options)
               else # :auto
                 execute_auto(intent, **options)
               end

      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      normalize_result(result, latency_ms: latency_ms, strategy: strategy)
    end

    private

    def execute_auto(intent, **options)
      if @config.auto_boot_mesh && !NativeCore.node_alive?
        NativeCore.start_node(@config.mesh_port)
      end

      if NativeCore.node_alive?
        begin
          return execute_p2p(intent)
        rescue ProviderError
          # fall through to cloud
        end
      end

      execute_cloud(intent, **options)
    end

    def execute_p2p(intent)
      unless NativeCore.node_alive?
        booted = NativeCore.start_node(@config.mesh_port)
        unless booted && NativeCore.node_alive?
          raise ProviderError.new(
            "Native mesh node is not alive (compile chimera_core or enable fallback)",
            provider: :p2p_mesh
          )
        end
      end

      payload = NativeCore.execute_wasm_payload(intent)
      if payload["ok"] == false
        raise ProviderError.new(
          payload["error"] || "native execute failed",
          provider: :p2p_mesh,
          body: payload
        )
      end

      Response.new(
        content: payload["output"].to_s,
        provider: :p2p_mesh,
        model: payload["engine"] || "chimera_core",
        usage: {},
        raw: payload,
        latency_ms: nil,
        fallback_used: false,
        cache_hit: false
      )
    end

    def execute_cloud(intent, providers: nil, **options)
      providers ||= @config.fallback_providers
      providers = Array(providers).map(&:to_sym)
      providers = @config.default_providers if providers.empty?

      @router.complete(
        prompt: intent,
        providers: providers,
        fallback: options.key?(:fallback) ? options[:fallback] : @config.fallback,
        system: options[:system],
        model: options[:model],
        **options.reject { |k, _| %i[system model fallback providers].include?(k) }
      )
    end

    def normalize_result(response, latency_ms:, strategy:)
      return response if response.is_a?(Response) && response.latency_ms

      Response.new(
        content: response.content,
        provider: response.provider,
        model: response.model,
        usage: response.usage,
        raw: (response.raw.is_a?(Hash) ? response.raw : { data: response.raw }).merge("strategy" => strategy.to_s),
        latency_ms: response.latency_ms || latency_ms,
        fallback_used: response.fallback_used,
        cache_hit: response.cache_hit
      )
    end
  end
end

# frozen_string_literal: true

module RubyLlmMesh
  class Configuration
    attr_accessor :default_providers, :fallback, :timeout, :max_retries,
                  :openai_api_key, :openai_base_url, :openai_model,
                  :anthropic_api_key, :anthropic_base_url, :anthropic_model,
                  :local_node_base_url, :local_node_model,
                  :circuit_failure_threshold, :circuit_reset_timeout,
                  :logger,
                  :mesh_port, :fallback_providers, :auto_boot_mesh,
                  :semantic_cache_enabled, :semantic_cache_threshold,
                  :semantic_cache_ttl, :semantic_cache_dimensions,
                  :redis_url, :semantic_cache_backend,
                  :peer_discovery_enabled, :peer_urls,
                  :peer_health_interval, :peer_health_timeout,
                  :peer_health_path

    def initialize
      @default_providers = %i[openai anthropic local_node]
      @fallback = true
      @timeout = 30
      @max_retries = 1

      @openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)
      @openai_base_url = ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com/v1")
      @openai_model = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")

      @anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
      @anthropic_base_url = ENV.fetch("ANTHROPIC_BASE_URL", "https://api.anthropic.com")
      @anthropic_model = ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-4-5")

      @local_node_base_url = ENV.fetch("LOCAL_NODE_BASE_URL", "http://127.0.0.1:11434")
      @local_node_model = ENV.fetch("LOCAL_NODE_MODEL", "llama3.2")

      @circuit_failure_threshold = 3
      @circuit_reset_timeout = 60
      @logger = nil

      # Sovereign mesh / native core
      @mesh_port = Integer(ENV.fetch("RUBY_LLM_MESH_PORT", "4233"))
      @auto_boot_mesh = ENV.fetch("RUBY_LLM_MESH_AUTO_BOOT", "true") == "true"
      @fallback_providers = %i[openai anthropic local_node]

      # Semantic cache — opt-in
      @semantic_cache_enabled = ENV.fetch("RUBY_LLM_MESH_SEMANTIC_CACHE", "false") == "true"
      @semantic_cache_threshold = Float(ENV.fetch("RUBY_LLM_MESH_CACHE_THRESHOLD", "0.92"))
      @semantic_cache_ttl = Integer(ENV.fetch("RUBY_LLM_MESH_CACHE_TTL", "3600"))
      @semantic_cache_dimensions = 256
      @redis_url = ENV.fetch("REDIS_URL", nil)
      @semantic_cache_backend = nil

      # Local peer mesh discovery / health
      @peer_discovery_enabled = ENV.fetch("RUBY_LLM_MESH_PEER_DISCOVERY", "false") == "true"
      peer_urls_env = ENV.fetch("RUBY_LLM_MESH_PEER_URLS", "")
      @peer_urls = peer_urls_env.empty? ? [] : peer_urls_env.split(",").map(&:strip).reject(&:empty?)
      @peer_health_interval = Integer(ENV.fetch("RUBY_LLM_MESH_PEER_HEALTH_INTERVAL", "30"))
      @peer_health_timeout = Integer(ENV.fetch("RUBY_LLM_MESH_PEER_HEALTH_TIMEOUT", "2"))
      @peer_health_path = ENV.fetch("RUBY_LLM_MESH_PEER_HEALTH_PATH", "/api/tags")
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      NativeCore.reset! if defined?(NativeCore)
      @configuration = Configuration.new
      Cache::SemanticCache.reset! if defined?(Cache::SemanticCache)
      Mesh::PeerRegistry.reset! if defined?(Mesh::PeerRegistry)
      Mesh::HealthMonitor.reset! if defined?(Mesh::HealthMonitor)
    end
  end
end

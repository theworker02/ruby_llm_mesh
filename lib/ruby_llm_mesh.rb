# frozen_string_literal: true

require_relative "ruby_llm_mesh/version"
require_relative "ruby_llm_mesh/errors"
require_relative "ruby_llm_mesh/configuration"
require_relative "ruby_llm_mesh/response"
require_relative "ruby_llm_mesh/circuit_breaker"
require_relative "ruby_llm_mesh/providers/base"
require_relative "ruby_llm_mesh/providers/openai"
require_relative "ruby_llm_mesh/providers/anthropic"
require_relative "ruby_llm_mesh/providers/local_node"
require_relative "ruby_llm_mesh/rag/chunker"
require_relative "ruby_llm_mesh/rag/embeddings"
require_relative "ruby_llm_mesh/rag/tools"
require_relative "ruby_llm_mesh/cache/memory_store"
require_relative "ruby_llm_mesh/cache/redis_store"
require_relative "ruby_llm_mesh/cache/semantic_cache"
require_relative "ruby_llm_mesh/mesh/peer_registry"
require_relative "ruby_llm_mesh/mesh/health_monitor"
require_relative "ruby_llm_mesh/native_core"
require_relative "ruby_llm_mesh/router"
require_relative "ruby_llm_mesh/sovereign_mesh"

# Optional Rails integration — only load railtie when Rails is already present
if defined?(Rails::Railtie)
  require_relative "ruby_llm_mesh/railtie"
end

module RubyLlmMesh
  class << self
    def complete(prompt:, providers: nil, fallback: nil, **options)
      Router.new.complete(prompt: prompt, providers: providers, fallback: fallback, **options)
    end

    def chat(**)
      complete(**)
    end

    # Sovereign mesh entrypoint — native P2P and/or real cloud failover.
    def execute(intent:, strategy: :auto, **options)
      SovereignMesh.new.execute(intent: intent, strategy: strategy, **options)
    end

    def boot_mesh!(port: configuration.mesh_port)
      NativeCore.start_node(port)
    end

    def mesh_alive?
      NativeCore.node_alive?
    end
  end
end

# Friendly alias matching the public DSL from the project overview
module AiAgentRouter
  def self.complete(...)
    RubyLlmMesh.complete(...)
  end

  def self.execute(...)
    RubyLlmMesh.execute(...)
  end

  def self.configure(&)
    RubyLlmMesh.configure(&)
  end

  def self.configuration
    RubyLlmMesh.configuration
  end

  def self.boot_mesh!(...)
    RubyLlmMesh.boot_mesh!(...)
  end

  def self.mesh_alive?
    RubyLlmMesh.mesh_alive?
  end
end

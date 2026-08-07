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
require_relative "ruby_llm_mesh/router"
require_relative "ruby_llm_mesh/rag/chunker"
require_relative "ruby_llm_mesh/rag/embeddings"
require_relative "ruby_llm_mesh/rag/tools"

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
  end
end

# Friendly alias matching the public DSL from the project overview
module AiAgentRouter
  def self.complete(...)
    RubyLlmMesh.complete(...)
  end

  def self.configure(&)
    RubyLlmMesh.configure(&)
  end

  def self.configuration
    RubyLlmMesh.configuration
  end
end

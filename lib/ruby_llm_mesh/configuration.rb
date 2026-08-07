# frozen_string_literal: true

module RubyLlmMesh
  class Configuration
    attr_accessor :default_providers, :fallback, :timeout, :max_retries,
                  :openai_api_key, :openai_base_url, :openai_model,
                  :anthropic_api_key, :anthropic_base_url, :anthropic_model,
                  :local_node_base_url, :local_node_model,
                  :circuit_failure_threshold, :circuit_reset_timeout,
                  :logger

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
      @configuration = Configuration.new
    end
  end
end

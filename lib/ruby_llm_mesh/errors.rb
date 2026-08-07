# frozen_string_literal: true

module RubyLlmMesh
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class ProviderError < Error
    attr_reader :provider, :status, :body

    def initialize(message, provider: nil, status: nil, body: nil)
      @provider = provider
      @status = status
      @body = body
      super(message)
    end
  end

  class RateLimitError < ProviderError; end
  class TimeoutError < ProviderError; end
  class AuthenticationError < ProviderError; end
  class CircuitOpenError < ProviderError; end

  class AllProvidersFailedError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      summary = errors.map { |provider, err| "#{provider}: #{err.message}" }.join("; ")
      super("All providers failed — #{summary}")
    end
  end
end

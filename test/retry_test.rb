# frozen_string_literal: true

require_relative "test_helper"

class RetryTest < Minitest::Test
  def setup
    super
    RubyLlmMesh.configure do |c|
      c.max_retries = 2
      c.retry_backoff = 0
    end
  end

  def test_retries_timeout_then_succeeds
    provider = counting_provider(:openai, fails: 2, error: RubyLlmMesh::TimeoutError.new("slow", provider: :openai),
                                          content: "recovered")

    with_stubbed_map(openai: provider) do
      response = RubyLlmMesh.complete(prompt: "hi", providers: [:openai], fallback: false)
      assert_equal "recovered", response.content
      assert_equal 3, provider.attempts
    end
  end

  def test_does_not_retry_authentication_errors
    provider = counting_provider(:openai, fails: 5,
                                          error: RubyLlmMesh::AuthenticationError.new("bad key", provider: :openai, status: 401),
                                          content: "nope")

    with_stubbed_map(openai: provider) do
      error = assert_raises(RubyLlmMesh::AllProvidersFailedError) do
        RubyLlmMesh.complete(prompt: "hi", providers: [:openai], fallback: false)
      end
      assert_kind_of RubyLlmMesh::AuthenticationError, error.errors[:openai]
      assert_equal 1, provider.attempts
    end
  end

  def test_retries_exhausted_then_falls_back
    openai = counting_provider(:openai, fails: 9, error: RubyLlmMesh::TimeoutError.new("down", provider: :openai),
                                        content: "never")
    anthropic = stub_provider(:anthropic, content: "from anthropic")

    with_stubbed_map(openai: openai, anthropic: anthropic) do
      response = RubyLlmMesh.complete(prompt: "hi", providers: %i[openai anthropic], fallback: true)
      assert_equal "from anthropic", response.content
      assert response.fallback_used
      assert_equal 3, openai.attempts
    end
  end

  def test_max_retries_zero_is_single_attempt
    RubyLlmMesh.configure { |c| c.max_retries = 0 }
    provider = counting_provider(:openai, fails: 1, error: RubyLlmMesh::TimeoutError.new("once", provider: :openai),
                                          content: "unused")

    with_stubbed_map(openai: provider) do
      assert_raises(RubyLlmMesh::AllProvidersFailedError) do
        RubyLlmMesh.complete(prompt: "hi", providers: [:openai], fallback: false)
      end
      assert_equal 1, provider.attempts
    end
  end

  private

  def counting_provider(name, fails:, error:, content:)
    box = { n: 0 }
    klass = Class.new(RubyLlmMesh::Providers::Base) do
      define_method(:name) { name }
      define_method(:complete) do |**|
        box[:n] += 1
        raise error if box[:n] <= fails

        RubyLlmMesh::Response.new(content: content, provider: name, model: "test", latency_ms: 1)
      end
      define_singleton_method(:attempts) { box[:n] }
    end
    klass
  end

  def with_stubbed_map(map)
    original = RubyLlmMesh::Router::PROVIDER_MAP
    RubyLlmMesh::Router.send(:remove_const, :PROVIDER_MAP)
    RubyLlmMesh::Router.const_set(:PROVIDER_MAP, map)
    yield
  ensure
    RubyLlmMesh::Router.send(:remove_const, :PROVIDER_MAP)
    RubyLlmMesh::Router.const_set(:PROVIDER_MAP, original)
  end
end

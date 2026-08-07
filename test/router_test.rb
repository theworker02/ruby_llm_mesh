# frozen_string_literal: true

require_relative "test_helper"

class RouterTest < Minitest::Test
  def test_complete_via_ai_agent_router_alias
    ok = stub_provider(:openai, content: "hello")
    with_stubbed_map(openai: ok) do
      response = AiAgentRouter.complete(prompt: "hi", providers: [:openai], fallback: false)
      assert_equal "hello", response.content
      assert_equal :openai, response.provider
      refute response.fallback_used
    end
  end

  def test_fallback_to_second_provider
    failer = stub_provider(:openai, fail_with: RubyLlmMesh::ProviderError.new("boom", provider: :openai))
    ok = stub_provider(:anthropic, content: "from anthropic")

    with_stubbed_map(openai: failer, anthropic: ok) do
      response = RubyLlmMesh.complete(prompt: "hi", providers: %i[openai anthropic], fallback: true)
      assert_equal "from anthropic", response.content
      assert_equal :anthropic, response.provider
      assert response.fallback_used
    end
  end

  def test_all_providers_failed_raises
    failer = stub_provider(:openai, fail_with: RubyLlmMesh::ProviderError.new("down", provider: :openai))

    with_stubbed_map(openai: failer) do
      error = assert_raises(RubyLlmMesh::AllProvidersFailedError) do
        RubyLlmMesh.complete(prompt: "hi", providers: [:openai], fallback: true)
      end
      assert error.errors.key?(:openai)
    end
  end

  def test_empty_prompt_raises
    assert_raises(ArgumentError) do
      RubyLlmMesh.complete(prompt: "  ", providers: [:openai])
    end
  end

  def test_skips_open_circuit
    failer = stub_provider(:openai, fail_with: RubyLlmMesh::ProviderError.new("down", provider: :openai))
    ok = stub_provider(:local_node, content: "local")

    with_stubbed_map(openai: failer, local_node: ok) do
      breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 1, reset_timeout: 60)
      1.times { breaker.record_failure(:openai) }
      assert_equal :open, breaker.state_for(:openai)

      router = RubyLlmMesh::Router.new(circuit_breaker: breaker)
      response = router.complete(prompt: "hi", providers: %i[openai local_node], fallback: true)
      assert_equal "local", response.content
      assert_equal :local_node, response.provider
    end
  end

  def test_open_circuit_respects_fallback_false
    ok = stub_provider(:local_node, content: "should-not-run")

    with_stubbed_map(openai: stub_provider(:openai), local_node: ok) do
      breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 1, reset_timeout: 60)
      breaker.record_failure(:openai)
      assert_equal :open, breaker.state_for(:openai)

      router = RubyLlmMesh::Router.new(circuit_breaker: breaker)
      error = assert_raises(RubyLlmMesh::AllProvidersFailedError) do
        router.complete(prompt: "hi", providers: %i[openai local_node], fallback: false)
      end
      assert error.errors.key?(:openai)
      refute error.errors.key?(:local_node)
    end
  end

  def test_unknown_provider_respects_fallback_false
    ok = stub_provider(:openai, content: "should-not-run")

    with_stubbed_map(openai: ok) do
      error = assert_raises(RubyLlmMesh::AllProvidersFailedError) do
        RubyLlmMesh.complete(prompt: "hi", providers: %i[not_a_provider openai], fallback: false)
      end
      assert error.errors.key?(:not_a_provider)
      refute error.errors.key?(:openai)
    end
  end

  def test_unknown_provider_falls_through_when_fallback_true
    ok = stub_provider(:openai, content: "recovered")

    with_stubbed_map(openai: ok) do
      response = RubyLlmMesh.complete(prompt: "hi", providers: %i[mystery openai], fallback: true)
      assert_equal "recovered", response.content
      assert_equal :openai, response.provider
      assert response.fallback_used
    end
  end

  private

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

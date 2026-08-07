# frozen_string_literal: true

require_relative "test_helper"

class SovereignMeshTest < Minitest::Test
  def setup
    super
    RubyLlmMesh.configure do |c|
      c.auto_boot_mesh = true
      c.mesh_port = 42_331
      c.semantic_cache_enabled = false
      c.fallback_providers = %i[openai anthropic]
    end
    RubyLlmMesh::NativeCore.reset!
  end

  def teardown
    RubyLlmMesh::NativeCore.reset!
    super
  end

  def test_execute_p2p_mesh_via_fallback
    response = RubyLlmMesh.execute(intent: "ping sovereign mesh", strategy: :p2p_mesh)
    assert_match(/intent|mesh|Native|Fallback/i, response.content)
    assert_equal :p2p_mesh, response.provider
    assert response.raw.is_a?(Hash)
    assert response.raw["ok"]
  end

  def test_execute_auto_uses_mesh_when_booted
    RubyLlmMesh.boot_mesh!(port: 42_332)
    assert RubyLlmMesh.mesh_alive?

    response = AiAgentRouter.execute(intent: "auto strategy check", strategy: :auto)
    assert_equal :p2p_mesh, response.provider
    refute_nil response.content
  end

  def test_execute_cloud_uses_real_providers
    ok = stub_provider(:openai, content: "cloud-real-response")
    with_stubbed_map(openai: ok) do
      RubyLlmMesh.configure { |c| c.auto_boot_mesh = false }
      RubyLlmMesh::NativeCore.reset!

      response = RubyLlmMesh.execute(
        intent: "summarize failover",
        strategy: :cloud,
        providers: [:openai]
      )
      assert_equal "cloud-real-response", response.content
      assert_equal :openai, response.provider
    end
  end

  def test_execute_openai_strategy
    ok = stub_provider(:openai, content: "from openai strategy")
    with_stubbed_map(openai: ok) do
      response = RubyLlmMesh.execute(intent: "hi", strategy: :openai)
      assert_equal "from openai strategy", response.content
      assert_equal :openai, response.provider
    end
  end

  def test_unknown_strategy_raises
    assert_raises(ArgumentError) do
      RubyLlmMesh.execute(intent: "x", strategy: :warp_drive)
    end
  end

  def test_empty_intent_raises
    assert_raises(ArgumentError) do
      RubyLlmMesh.execute(intent: "  ", strategy: :p2p_mesh)
    end
  end

  def test_native_core_fallback_without_library
    # Force fallback path regardless of whether cargo lib exists
    RubyLlmMesh::NativeCore.reset!
    RubyLlmMesh::NativeCore.instance_variable_set(:@boot_attempted, true)
    RubyLlmMesh::NativeCore.instance_variable_set(:@native_loaded, false)

    assert RubyLlmMesh::NativeCore.start_node(42_333)
    assert RubyLlmMesh::NativeCore.node_alive?
    payload = RubyLlmMesh::NativeCore.execute_wasm_payload("fallback intent")
    assert_equal "ruby_fallback", payload["engine"]
    assert_match(/Fallback/, payload["output"])
    RubyLlmMesh::NativeCore.stop_node
    refute RubyLlmMesh::NativeCore.node_alive?
  end

  def test_complete_api_still_works
    ok = stub_provider(:anthropic, content: "compat")
    with_stubbed_map(anthropic: ok) do
      response = AiAgentRouter.complete(prompt: "hello", providers: [:anthropic])
      assert_equal "compat", response.content
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

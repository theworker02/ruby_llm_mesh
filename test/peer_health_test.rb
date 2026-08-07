# frozen_string_literal: true

require_relative "test_helper"

class PeerHealthTest < Minitest::Test
  def setup
    super
    RubyLlmMesh.configure do |c|
      c.peer_discovery_enabled = true
      c.peer_urls = %w[http://127.0.0.1:11434 http://127.0.0.1:1234]
      c.local_node_base_url = "http://127.0.0.1:11434"
      c.peer_health_timeout = 1
      c.peer_health_interval = 60
      c.semantic_cache_enabled = false
    end
    RubyLlmMesh::Mesh::PeerRegistry.reset!
    RubyLlmMesh::Mesh::HealthMonitor.reset!
  end

  def teardown
    RubyLlmMesh::Mesh::HealthMonitor.reset!
    super
  end

  def test_peer_registry_seeds_urls
    registry = RubyLlmMesh::Mesh::PeerRegistry.instance
    urls = registry.all_urls
    assert_includes urls, "http://127.0.0.1:11434"
    assert_includes urls, "http://127.0.0.1:1234"
  end

  def test_mark_unhealthy_removes_from_healthy_list
    registry = RubyLlmMesh::Mesh::PeerRegistry.instance
    registry.mark_unhealthy("http://127.0.0.1:11434", error: "down")
    healthy = registry.healthy_urls
    refute_includes healthy, "http://127.0.0.1:11434"
    assert_includes healthy, "http://127.0.0.1:1234"
  end

  def test_health_monitor_marks_peer_from_http
    stub_request(:get, "http://127.0.0.1:11434/api/tags").to_return(status: 200, body: "{}")
    stub_request(:get, "http://127.0.0.1:1234/api/tags").to_return(status: 500, body: "err")
    stub_request(:get, "http://127.0.0.1:1234/v1/models").to_return(status: 500, body: "err")

    monitor = RubyLlmMesh::Mesh::HealthMonitor.instance
    monitor.check_all!

    registry = RubyLlmMesh::Mesh::PeerRegistry.instance
    assert_includes registry.healthy_urls, "http://127.0.0.1:11434"
    refute_includes registry.healthy_urls, "http://127.0.0.1:1234"
  end

  def test_local_node_reroutes_to_healthy_peer
    RubyLlmMesh.configure do |c|
      c.peer_discovery_enabled = true
      c.peer_urls = %w[http://peer-a:11434 http://peer-b:11434]
      c.local_node_base_url = "http://peer-a:11434"
      c.local_node_model = "llama3.2"
    end
    RubyLlmMesh::Mesh::PeerRegistry.reset!

    registry = RubyLlmMesh::Mesh::PeerRegistry.instance
    registry.mark_unhealthy("http://peer-a:11434", error: "timeout")

    stub_request(:post, "http://peer-b:11434/v1/chat/completions")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "llama3.2",
          choices: [{ message: { content: "from peer-b" } }],
          usage: {}
        }.to_json
      )

    provider = RubyLlmMesh::Providers::LocalNode.new
    response = provider.complete(prompt: "hi")
    assert_equal "from peer-b", response.content
    assert_equal "http://peer-b:11434", response.raw["_peer"]
  end

  def test_local_node_tries_next_peer_on_failure
    RubyLlmMesh.configure do |c|
      c.peer_discovery_enabled = true
      c.peer_urls = %w[http://peer-a:11434 http://peer-b:11434]
      c.local_node_base_url = "http://peer-a:11434"
      c.local_node_model = "llama3.2"
    end
    RubyLlmMesh::Mesh::PeerRegistry.reset!

    stub_request(:post, "http://peer-a:11434/v1/chat/completions")
      .to_return(status: 429, body: "rate limited")
    stub_request(:post, "http://peer-b:11434/v1/chat/completions")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "llama3.2",
          choices: [{ message: { content: "rerouted" } }],
          usage: {}
        }.to_json
      )

    provider = RubyLlmMesh::Providers::LocalNode.new
    response = provider.complete(prompt: "hi")
    assert_equal "rerouted", response.content

    registry = RubyLlmMesh::Mesh::PeerRegistry.instance
    refute_includes registry.healthy_urls, "http://peer-a:11434"
  end

  def test_rate_limit_opens_circuit_for_fast_reroute
    RubyLlmMesh.configure { |c| c.peer_discovery_enabled = false }

    failer = stub_provider(
      :openai,
      fail_with: RubyLlmMesh::RateLimitError.new("429", provider: :openai, status: 429)
    )
    ok = stub_provider(:anthropic, content: "ok")

    original = RubyLlmMesh::Router::PROVIDER_MAP
    RubyLlmMesh::Router.send(:remove_const, :PROVIDER_MAP)
    RubyLlmMesh::Router.const_set(:PROVIDER_MAP, { openai: failer, anthropic: ok })

    breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 3, reset_timeout: 60)
    router = RubyLlmMesh::Router.new(circuit_breaker: breaker)
    response = router.complete(prompt: "hi", providers: %i[openai anthropic], fallback: true)
    assert_equal "ok", response.content
    assert_equal :open, breaker.state_for(:openai)
  ensure
    RubyLlmMesh::Router.send(:remove_const, :PROVIDER_MAP)
    RubyLlmMesh::Router.const_set(:PROVIDER_MAP, original)
  end

  def test_local_mesh_alias_maps_to_local_node
    assert_equal RubyLlmMesh::Providers::LocalNode, RubyLlmMesh::Router::PROVIDER_MAP[:local_mesh]
  end
end

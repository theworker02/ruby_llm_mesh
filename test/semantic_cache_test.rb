# frozen_string_literal: true

require_relative "test_helper"

class SemanticCacheTest < Minitest::Test
  def setup
    super
    RubyLlmMesh.configure do |c|
      c.semantic_cache_enabled = true
      c.semantic_cache_threshold = 0.92
      c.semantic_cache_ttl = 3600
      c.semantic_cache_backend = :memory
      c.redis_url = nil
    end
    RubyLlmMesh::Cache::SemanticCache.reset!
  end

  def test_stores_and_looks_up_identical_prompt
    cache = RubyLlmMesh::Cache::SemanticCache.new(config: RubyLlmMesh.configuration)
    response = RubyLlmMesh::Response.new(
      content: "cached answer",
      provider: :openai,
      model: "gpt-test",
      usage: { "total_tokens" => 10 }
    )

    assert cache.store_response("What is a circuit breaker?", response)
    hit = cache.lookup("What is a circuit breaker?")
    refute_nil hit
    assert hit.cache_hit
    assert_equal "cached answer", hit.content
    assert_equal :semantic_cache, hit.provider
  end

  def test_lookup_miss_below_threshold
    cache = RubyLlmMesh::Cache::SemanticCache.new(config: RubyLlmMesh.configuration)
    response = RubyLlmMesh::Response.new(content: "weather", provider: :openai, model: "t")
    cache.store_response("sunny day in paris weather forecast", response)

    miss = cache.lookup("how do redis streams work under high load")
    assert_nil miss
  end

  def test_router_returns_cache_hit
    ok = stub_provider(:openai, content: "fresh")
    with_stubbed_map(openai: ok) do
      first = RubyLlmMesh.complete(prompt: "explain semantic caching briefly", providers: [:openai])
      assert_equal "fresh", first.content
      refute first.cache_hit

      second = RubyLlmMesh.complete(prompt: "explain semantic caching briefly", providers: [:openai])
      assert second.cache_hit
      assert_equal "fresh", second.content
      assert_equal :semantic_cache, second.provider
    end
  end

  def test_skip_cache_bypasses_lookup
    ok = stub_provider(:openai, content: "fresh")
    with_stubbed_map(openai: ok) do
      RubyLlmMesh.complete(prompt: "same prompt again", providers: [:openai])
      again = RubyLlmMesh.complete(prompt: "same prompt again", providers: [:openai], skip_cache: true)
      refute again.cache_hit
      assert_equal :openai, again.provider
    end
  end

  def test_disabled_by_default
    RubyLlmMesh.reset_configuration!
    refute RubyLlmMesh.configuration.semantic_cache_enabled
  end

  def test_memory_store_ttl_expiry
    store = RubyLlmMesh::Cache::MemoryStore.new
    store.write(id: "1", prompt: "p", embedding: [1.0], payload: { "content" => "x" }, ttl: -1)
    # expires_at in the past
    store.instance_variable_get(:@entries).first.expires_at = Time.now - 10
    assert_equal 0, store.size
  end

  def test_redis_store_requires_gem_or_raises
    skip "redis gem is installed" if RubyLlmMesh::Cache::RedisStore.redis_available?

    assert_raises(RubyLlmMesh::ConfigurationError) do
      RubyLlmMesh::Cache::RedisStore.new(url: "redis://localhost:6379/0")
    end
  end

  def test_fake_redis_store_roundtrip
    fake = FakeRedisStore.new
    config = RubyLlmMesh.configuration
    cache = RubyLlmMesh::Cache::SemanticCache.new(config: config, store: fake)
    response = RubyLlmMesh::Response.new(content: "via redis", provider: :anthropic, model: "c")
    cache.store_response("distributed cache question", response)
    hit = cache.lookup("distributed cache question")
    refute_nil hit
    assert_equal "via redis", hit.content
  end

  private

  class FakeRedisStore
    def initialize
      @entries = {}
    end

    def all
      @entries.values.map(&:dup)
    end

    def write(id:, prompt:, embedding:, payload:, ttl:)
      expires_at = ttl && ttl.positive? ? Time.now + ttl : nil
      @entries[id] = RubyLlmMesh::Cache::MemoryStore::Entry.new(
        id: id, prompt: prompt, embedding: embedding, payload: payload, expires_at: expires_at
      )
      true
    end

    def clear!
      @entries.clear
    end

    def size
      @entries.length
    end
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

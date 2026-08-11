# frozen_string_literal: true

require_relative "test_helper"

class BudgetTest < Minitest::Test
  def setup
    super
    RubyLlmMesh.configure do |c|
      c.budget_enabled = true
      c.budget_max_tokens = 100
      c.budget_max_usd = 0.01
      c.budget_prices = {
        "test-model" => { input_per_1k: 0.001, output_per_1k: 0.002 }
      }
    end
    RubyLlmMesh::Budget.reset!
  end

  def test_disabled_by_default
    RubyLlmMesh.reset_configuration!
    refute RubyLlmMesh.configuration.budget_enabled
  end

  def test_budget_status_reflects_consumption
    budget = RubyLlmMesh::Budget.instance
    budget.consume!(usage: { "total_tokens" => 25, "prompt_tokens" => 20, "completion_tokens" => 5 },
                    provider: :openai, model: "test-model")

    status = RubyLlmMesh.budget_status
    assert status[:enabled]
    assert_equal 25, status[:tokens_consumed]
    assert_equal 75, status[:tokens_remaining]
    assert status[:usd_consumed].positive?
  end

  def test_pre_check_blocks_before_provider_call
    provider = Class.new(RubyLlmMesh::Providers::Base) do
      define_method(:name) { :openai }
      define_method(:complete) do |**|
        flunk "provider should not be called when budget is exceeded"
      end
    end

    with_stubbed_map(openai: provider) do
      budget = RubyLlmMesh::Budget.instance
      budget.consume!(usage: { "total_tokens" => 95 }, provider: :openai, model: "test-model")

      error = assert_raises(RubyLlmMesh::BudgetExceededError) do
        RubyLlmMesh.complete(prompt: "a" * 200, providers: [:openai], fallback: false)
      end
      assert_equal :token, error.dimension
    end
  end

  def test_consume_after_success_tracks_usage
    provider = Class.new(RubyLlmMesh::Providers::Base) do
      define_method(:name) { :openai }
      define_method(:complete) do |**|
        RubyLlmMesh::Response.new(
          content: "done",
          provider: :openai,
          model: "test-model",
          usage: { "total_tokens" => 40, "prompt_tokens" => 30, "completion_tokens" => 10 },
          latency_ms: 1
        )
      end
    end

    with_stubbed_map(openai: provider) do
      response = RubyLlmMesh.complete(prompt: "hello", providers: [:openai], fallback: false)
      assert_equal "done", response.content
      assert_equal 40, RubyLlmMesh.budget_status[:tokens_consumed]
    end
  end

  def test_ai_agent_router_budget_status_alias
    RubyLlmMesh::Budget.instance.consume!(usage: { "total_tokens" => 10 }, provider: :openai, model: "test-model")
    assert_equal RubyLlmMesh.budget_status, AiAgentRouter.budget_status
  end

  def test_cache_hit_does_not_consume_budget
    RubyLlmMesh.configure do |c|
      c.semantic_cache_enabled = true
      c.semantic_cache_backend = :memory
    end
    RubyLlmMesh::Cache::SemanticCache.reset!

    ok = stub_provider(:openai, content: "cached")
    with_stubbed_map(openai: ok) do
      RubyLlmMesh.complete(prompt: "same prompt", providers: [:openai])
      before = RubyLlmMesh.budget_status[:tokens_consumed]
      RubyLlmMesh.complete(prompt: "same prompt", providers: [:openai])
      assert_equal before, RubyLlmMesh.budget_status[:tokens_consumed]
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

# frozen_string_literal: true

require_relative "test_helper"

class CircuitBreakerTest < Minitest::Test
  def test_opens_after_threshold
    breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 2, reset_timeout: 60)

    assert breaker.allow?(:openai)
    breaker.record_failure(:openai)
    assert_equal :closed, breaker.state_for(:openai)
    assert breaker.allow?(:openai)

    breaker.record_failure(:openai)
    assert_equal :open, breaker.state_for(:openai)
    refute breaker.allow?(:openai)
  end

  def test_success_resets_failures
    breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 2, reset_timeout: 60)
    breaker.record_failure(:anthropic)
    breaker.record_success(:anthropic)
    assert_equal :closed, breaker.state_for(:anthropic)
    assert_equal 0, breaker.instance_variable_get(:@states)[:anthropic][:failures]
  end

  def test_half_open_after_timeout
    breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 1, reset_timeout: 0)
    breaker.record_failure(:local_node)
    assert_equal :open, breaker.state_for(:local_node)

    # reset_timeout 0 => allow? transitions to half_open (single probe)
    assert breaker.allow?(:local_node)
    assert_equal :half_open, breaker.state_for(:local_node)
  end

  def test_half_open_allows_only_one_probe
    breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 1, reset_timeout: 0)
    breaker.record_failure(:openai)
    assert breaker.allow?(:openai) # OPEN → HALF_OPEN probe
    refute breaker.allow?(:openai) # further probes blocked until outcome recorded
    assert_equal :half_open, breaker.state_for(:openai)
  end

  def test_half_open_failure_reopens
    breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 1, reset_timeout: 0)
    breaker.record_failure(:openai)
    assert breaker.allow?(:openai) # half-open
    breaker.record_failure(:openai)
    assert_equal :open, breaker.state_for(:openai)
  end

  def test_reset
    breaker = RubyLlmMesh::CircuitBreaker.new(failure_threshold: 1, reset_timeout: 60)
    breaker.record_failure(:openai)
    breaker.reset!(:openai)
    assert_equal :closed, breaker.state_for(:openai)
  end
end

# frozen_string_literal: true

module RubyLlmMesh
  # Simple per-provider circuit breaker shared across the process.
  class CircuitBreaker
    OPEN = :open
    CLOSED = :closed
    HALF_OPEN = :half_open

    def initialize(failure_threshold:, reset_timeout:)
      @failure_threshold = failure_threshold
      @reset_timeout = reset_timeout
      @states = Hash.new { |h, k| h[k] = { failures: 0, opened_at: nil, state: CLOSED } }
      @mutex = Mutex.new
    end

    def allow?(provider)
      @mutex.synchronize do
        entry = @states[provider]
        case entry[:state]
        when CLOSED
          true
        when OPEN
          if Time.now - entry[:opened_at] >= @reset_timeout
            entry[:state] = HALF_OPEN
            true
          else
            false
          end
        when HALF_OPEN
          true
        end
      end
    end

    def record_success(provider)
      @mutex.synchronize do
        @states[provider] = { failures: 0, opened_at: nil, state: CLOSED }
      end
    end

    def record_failure(provider)
      @mutex.synchronize do
        entry = @states[provider]
        entry[:failures] += 1
        if entry[:failures] >= @failure_threshold || entry[:state] == HALF_OPEN
          entry[:state] = OPEN
          entry[:opened_at] = Time.now
        end
      end
    end

    def state_for(provider)
      @mutex.synchronize { @states[provider][:state] }
    end

    def reset!(provider = nil)
      @mutex.synchronize do
        if provider
          @states.delete(provider)
        else
          @states.clear
        end
      end
    end
  end
end

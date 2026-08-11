# frozen_string_literal: true

module RubyLlmMesh
  class Budget
    DEFAULT_PRICES = {
      input_per_1k: 0.00015,
      output_per_1k: 0.0006
    }.freeze

    attr_reader :tokens_consumed, :usd_consumed

    def initialize(config: RubyLlmMesh.configuration)
      @config = config
      @tokens_consumed = 0
      @usd_consumed = 0.0
      @mutex = Mutex.new
    end

    def enabled?
      @config.budget_enabled
    end

    def check!(estimated_tokens: 0, estimated_usd: 0.0)
      return unless enabled?

      @mutex.synchronize do
        raise_budget_exceeded!("token", @tokens_consumed, @config.budget_max_tokens) if token_limit? && (@tokens_consumed + estimated_tokens) > @config.budget_max_tokens
        raise_budget_exceeded!("usd", @usd_consumed, @config.budget_max_usd) if usd_limit? && (@usd_consumed + estimated_usd) > @config.budget_max_usd
      end
    end

    def consume!(usage:, provider:, model:)
      return unless enabled?

      tokens = self.class.extract_tokens(usage)
      usd = self.class.compute_cost(usage, provider: provider, model: model, config: @config)

      @mutex.synchronize do
        @tokens_consumed += tokens
        @usd_consumed += usd
        raise_budget_exceeded!("token", @tokens_consumed, @config.budget_max_tokens) if token_limit? && @tokens_consumed > @config.budget_max_tokens
        raise_budget_exceeded!("usd", @usd_consumed, @config.budget_max_usd) if usd_limit? && @usd_consumed > @config.budget_max_usd
      end
    end

    def status
      {
        enabled: enabled?,
        tokens_consumed: @tokens_consumed,
        tokens_max: @config.budget_max_tokens,
        tokens_remaining: tokens_remaining,
        usd_consumed: @usd_consumed.round(6),
        usd_max: @config.budget_max_usd,
        usd_remaining: usd_remaining
      }
    end

    def reset!
      @mutex.synchronize do
        @tokens_consumed = 0
        @usd_consumed = 0.0
      end
    end

    class << self
      def instance(config: RubyLlmMesh.configuration)
        @instances ||= {}
        @instances[config.object_id] ||= new(config: config)
      end

      def reset!
        @instances = {}
      end

      def estimate_tokens(prompt:, system: nil, max_tokens: nil)
        text = [system, prompt].compact.join("\n")
        estimated = (text.length / 4.0).ceil
        estimated += max_tokens.to_i if max_tokens
        estimated
      end

      def estimate_usd(tokens:, model: nil, config: RubyLlmMesh.configuration)
        prices = resolve_prices(config, model)
        (tokens / 1000.0) * prices[:input_per_1k]
      end

      def resolve_prices(config, model)
        table = config.budget_prices || {}
        entry = model ? table[model.to_s] || table[model.to_sym] : nil
        entry ||= table[:default] || table["default"]
        DEFAULT_PRICES.merge(entry || {})
      end

      def compute_cost(usage, provider:, model:, config: RubyLlmMesh.configuration)
        prices = resolve_prices(config, model)
        prompt_tokens = usage_value(usage, :prompt_tokens, :input_tokens)
        completion_tokens = usage_value(usage, :completion_tokens, :output_tokens)
        input_cost = (prompt_tokens / 1000.0) * prices[:input_per_1k]
        output_cost = (completion_tokens / 1000.0) * prices[:output_per_1k]
        input_cost + output_cost
      end

      def extract_tokens(usage)
        usage_value(usage, :total_tokens, :prompt_tokens, :completion_tokens, :input_tokens, :output_tokens)
      end

      private

      def usage_value(usage, *keys)
        hash = usage.is_a?(Hash) ? usage : {}
        keys.each do |key|
          value = hash[key] || hash[key.to_s]
          return value.to_i if value
        end
        hash["total_tokens"].to_i
      end
    end

    private

    def token_limit?
      !@config.budget_max_tokens.nil?
    end

    def usd_limit?
      !@config.budget_max_usd.nil?
    end

    def tokens_remaining
      return nil unless token_limit?

      [@config.budget_max_tokens - @tokens_consumed, 0].max
    end

    def usd_remaining
      return nil unless usd_limit?

      [(@config.budget_max_usd - @usd_consumed).round(6), 0.0].max
    end

    def raise_budget_exceeded!(dimension, consumed, limit)
      raise BudgetExceededError.new(
        "Budget exceeded: #{dimension} limit #{limit} (#{consumed} consumed)",
        dimension: dimension.to_sym,
        consumed: consumed,
        limit: limit
      )
    end
  end
end

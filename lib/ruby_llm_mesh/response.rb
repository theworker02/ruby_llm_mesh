# frozen_string_literal: true

module RubyLlmMesh
  class Response
    attr_reader :content, :provider, :model, :usage, :raw, :latency_ms, :fallback_used, :cache_hit

    def initialize(content:, provider:, model: nil, usage: {}, raw: nil, latency_ms: nil,
                   fallback_used: false, cache_hit: false)
      @content = content
      @provider = provider
      @model = model
      @usage = usage || {}
      @raw = raw
      @latency_ms = latency_ms
      @fallback_used = fallback_used
      @cache_hit = cache_hit
    end

    def text
      content
    end

    def to_s
      content.to_s
    end

    def to_h
      {
        content: content,
        provider: provider,
        model: model,
        usage: usage,
        latency_ms: latency_ms,
        fallback_used: fallback_used,
        cache_hit: cache_hit
      }
    end
  end
end

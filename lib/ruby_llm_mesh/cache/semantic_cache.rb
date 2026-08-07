# frozen_string_literal: true

require "digest"
require "securerandom"
require_relative "memory_store"
require_relative "redis_store"

module RubyLlmMesh
  module Cache
    # Distributed (or process-local) semantic response cache.
    # Embeds prompts via Rag::Embeddings and matches with cosine similarity.
    class SemanticCache
      class << self
        def instance(config: RubyLlmMesh.configuration)
          @instance ||= new(config: config)
        end

        def reset!
          @instance&.clear!
          @instance = nil
        end
      end

      attr_reader :store, :embedder

      def initialize(config: RubyLlmMesh.configuration, store: nil, embedder: nil)
        @config = config
        @embedder = embedder || Rag::Embeddings.new(dimensions: config.semantic_cache_dimensions)
        @store = store || build_store
      end

      def enabled?
        !!@config.semantic_cache_enabled
      end

      def lookup(prompt, system: nil)
        return nil unless enabled?

        query = cache_key_text(prompt, system)
        query_vec = @embedder.embed(query)
        threshold = @config.semantic_cache_threshold
        best = nil
        best_score = -1.0

        @store.all.each do |entry|
          next if entry.expires_at && entry.expires_at <= Time.now
          next unless entry.embedding.is_a?(Array) && entry.embedding.length == query_vec.length

          score = @embedder.cosine_similarity(query_vec, entry.embedding)
          if score >= threshold && score > best_score
            best = entry
            best_score = score
          end
        end

        return nil unless best

        payload = best.payload || {}
        Response.new(
          content: payload["content"] || payload[:content],
          provider: :semantic_cache,
          model: payload["model"] || payload[:model],
          usage: payload["usage"] || payload[:usage] || {},
          raw: { cache_id: best.id, similarity: best_score, original_provider: payload["provider"] },
          latency_ms: 0,
          fallback_used: false,
          cache_hit: true
        )
      end

      def store_response(prompt, response, system: nil)
        return false unless enabled?
        return false if response.nil? || response.cache_hit

        query = cache_key_text(prompt, system)
        embedding = @embedder.embed(query)
        id = Digest::SHA256.hexdigest(query)[0, 32]
        payload = {
          "content" => response.content,
          "provider" => response.provider.to_s,
          "model" => response.model,
          "usage" => response.usage
        }
        @store.write(
          id: id,
          prompt: query,
          embedding: embedding,
          payload: payload,
          ttl: @config.semantic_cache_ttl
        )
      end

      def clear!
        @store.clear!
      end

      private

      def cache_key_text(prompt, system)
        [system.to_s.strip, prompt.to_s.strip].reject(&:empty?).join("\n---\n")
      end

      def build_store
        backend = @config.semantic_cache_backend
        backend = infer_backend if backend.nil?

        case backend.to_sym
        when :redis
          RedisStore.new(url: @config.redis_url)
        when :memory
          MemoryStore.new
        else
          raise ConfigurationError, "Unknown semantic_cache_backend: #{backend.inspect}"
        end
      end

      def infer_backend
        if @config.redis_url && !@config.redis_url.to_s.empty? && RedisStore.redis_available?
          :redis
        else
          :memory
        end
      end
    end
  end
end

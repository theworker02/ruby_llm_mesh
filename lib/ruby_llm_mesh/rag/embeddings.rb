# frozen_string_literal: true

module RubyLlmMesh
  module Rag
    # Zero-dependency bag-of-words style embeddings for local prototyping.
    # Swap for a real embedding provider in production.
    class Embeddings
      def initialize(dimensions: 256)
        @dimensions = dimensions
      end

      def embed(text)
        vector = Array.new(@dimensions, 0.0)
        tokenize(text).each do |token|
          index = stable_hash(token) % @dimensions
          vector[index] += 1.0
        end
        normalize!(vector)
        vector
      end

      def embed_many(texts)
        Array(texts).map { |t| embed(t) }
      end

      def cosine_similarity(a, b)
        raise ArgumentError, "vectors must match length" unless a.length == b.length

        dot = 0.0
        a.each_index { |i| dot += a[i] * b[i] }
        dot
      end

      def top_k(query, documents, k: 3)
        query_vec = embed(query)
        scored = documents.map do |doc|
          text = doc.is_a?(Hash) ? doc[:text] || doc["text"] : doc.to_s
          score = cosine_similarity(query_vec, embed(text))
          { document: doc, score: score }
        end
        scored.sort_by { |row| -row[:score] }.first(k)
      end

      private

      def tokenize(text)
        text.to_s.downcase.scan(/[a-z0-9_]+/)
      end

      def stable_hash(token)
        # FNV-1a 32-bit
        hash = 2166136261
        token.each_byte do |byte|
          hash ^= byte
          hash = (hash * 16777619) & 0xffffffff
        end
        hash
      end

      def normalize!(vector)
        norm = Math.sqrt(vector.sum { |v| v * v })
        return vector if norm.zero?

        vector.map! { |v| v / norm }
      end
    end
  end
end

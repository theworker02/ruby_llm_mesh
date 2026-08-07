# frozen_string_literal: true

module RubyLlmMesh
  module Cache
    # Process-local vector entry store used when Redis is unavailable.
    class MemoryStore
      Entry = Struct.new(:id, :prompt, :embedding, :payload, :expires_at, keyword_init: true)

      def initialize
        @entries = []
        @mutex = Mutex.new
      end

      def all
        @mutex.synchronize do
          now = Time.now
          @entries.reject! { |e| e.expires_at && e.expires_at <= now }
          @entries.map(&:dup)
        end
      end

      def write(id:, prompt:, embedding:, payload:, ttl:)
        expires_at = ttl && ttl.positive? ? Time.now + ttl : nil
        entry = Entry.new(
          id: id,
          prompt: prompt,
          embedding: embedding,
          payload: payload,
          expires_at: expires_at
        )
        @mutex.synchronize do
          @entries.reject! { |e| e.id == id }
          @entries << entry
        end
        true
      end

      def clear!
        @mutex.synchronize { @entries.clear }
      end

      def size
        all.length
      end
    end
  end
end

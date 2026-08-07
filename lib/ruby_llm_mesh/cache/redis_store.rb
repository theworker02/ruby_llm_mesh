# frozen_string_literal: true

require "json"
require "securerandom"

module RubyLlmMesh
  module Cache
    # Redis-backed store for distributed semantic cache entries.
    # Requires the optional `redis` gem — soft-loaded only when configured.
    class RedisStore
      INDEX_KEY = "ruby_llm_mesh:semantic_cache:index"
      ENTRY_PREFIX = "ruby_llm_mesh:semantic_cache:entry:"

      def self.redis_available?
        return @redis_available if defined?(@redis_available) && !@redis_available.nil?

        begin
          require "redis"
          @redis_available = true
        rescue LoadError
          @redis_available = false
        end
      end

      def initialize(url:)
        unless self.class.redis_available?
          raise ConfigurationError,
                "semantic cache backend :redis requires the optional `redis` gem — " \
                "add `gem \"redis\"` to your Gemfile or omit redis_url to use memory store"
        end

        @redis = ::Redis.new(url: url)
      end

      def all
        ids = @redis.smembers(INDEX_KEY)
        stale = []
        entries = ids.filter_map do |id|
          raw = @redis.get("#{ENTRY_PREFIX}#{id}")
          unless raw
            stale << id
            next
          end

          data = JSON.parse(raw)
          MemoryStore::Entry.new(
            id: id,
            prompt: data["prompt"],
            embedding: data["embedding"],
            payload: data["payload"],
            expires_at: data["expires_at"] ? Time.at(data["expires_at"]) : nil
          )
        rescue JSON::ParserError
          stale << id
          nil
        end
        cleanup_stale_index!(stale)
        entries
      end

      def write(id:, prompt:, embedding:, payload:, ttl:)
        id ||= SecureRandom.uuid
        expires_at = ttl && ttl.positive? ? Time.now.to_i + ttl : nil
        data = JSON.generate(
          "prompt" => prompt,
          "embedding" => embedding,
          "payload" => payload,
          "expires_at" => expires_at
        )
        key = "#{ENTRY_PREFIX}#{id}"
        if ttl && ttl.positive?
          @redis.setex(key, ttl, data)
        else
          @redis.set(key, data)
        end
        begin
          @redis.sadd(INDEX_KEY, [id])
        rescue ArgumentError, TypeError, Redis::CommandError
          @redis.sadd(INDEX_KEY, id)
        end
        true
      end

      def clear!
        ids = @redis.smembers(INDEX_KEY)
        keys = ids.map { |id| "#{ENTRY_PREFIX}#{id}" }
        @redis.del(*keys) if keys.any?
        @redis.del(INDEX_KEY)
      end

      def size
        all.length
      end

      private

      def cleanup_stale_index!(ids)
        return if ids.nil? || ids.empty?

        ids.each do |id|
          begin
            @redis.srem(INDEX_KEY, [id])
          rescue ArgumentError, TypeError, Redis::CommandError
            @redis.srem(INDEX_KEY, id)
          end
        end
      end
    end
  end
end

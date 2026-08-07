# frozen_string_literal: true

module RubyLlmMesh
  module Mesh
    # Registry of local LLM peer base URLs (Ollama, LM Studio, etc.).
    class PeerRegistry
      Peer = Struct.new(:url, :healthy, :last_checked_at, :last_error, keyword_init: true)

      class << self
        def instance(config: RubyLlmMesh.configuration)
          @instance ||= new(config: config)
        end

        def reset!
          @instance = nil
        end
      end

      def initialize(config: RubyLlmMesh.configuration)
        @config = config
        @mutex = Mutex.new
        @peers = {}
        seed_from_config!
      end

      def enabled?
        !!@config.peer_discovery_enabled || !peer_urls.empty?
      end

      def register(url)
        normalized = normalize_url(url)
        return if normalized.empty?

        @mutex.synchronize do
          @peers[normalized] ||= Peer.new(url: normalized, healthy: true, last_checked_at: nil, last_error: nil)
        end
      end

      def unregister(url)
        @mutex.synchronize { @peers.delete(normalize_url(url)) }
      end

      def mark_healthy(url)
        update_peer(url) do |peer|
          peer.healthy = true
          peer.last_error = nil
          peer.last_checked_at = Time.now
        end
      end

      def mark_unhealthy(url, error: nil)
        update_peer(url) do |peer|
          peer.healthy = false
          peer.last_error = error&.to_s
          peer.last_checked_at = Time.now
        end
      end

      def healthy_urls
        seed_from_config!
        @mutex.synchronize do
          # Only return peers currently marked healthy. When every peer is
          # unhealthy, return [] so callers (e.g. LocalNode) can apply their
          # own last-resort fallback — never reintroduce unhealthy URLs.
          @peers.values.select(&:healthy).map(&:url)
        end
      end

      def all_urls
        seed_from_config!
        @mutex.synchronize do
          keys = @peers.keys.dup
          keys.empty? ? peer_urls : keys
        end
      end

      def peer_urls
        urls = Array(@config.peer_urls).map { |u| normalize_url(u) }.reject(&:empty?)
        primary = normalize_url(@config.local_node_base_url)
        ([primary] + urls).uniq
      end

      def each_peer
        seed_from_config!
        @mutex.synchronize { @peers.values.map(&:dup) }.each { |peer| yield peer }
      end

      def clear!
        @mutex.synchronize { @peers.clear }
      end

      private

      def seed_from_config!
        peer_urls.each { |url| register(url) }
      end

      def update_peer(url)
        normalized = normalize_url(url)
        @mutex.synchronize do
          peer = @peers[normalized] || Peer.new(url: normalized, healthy: true)
          yield peer
          @peers[normalized] = peer
        end
      end

      def normalize_url(url)
        url.to_s.strip.chomp("/")
      end
    end
  end
end

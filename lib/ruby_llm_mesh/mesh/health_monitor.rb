# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module RubyLlmMesh
  module Mesh
    # Pings local LLM peers and marks them healthy/unhealthy for routing.
    class HealthMonitor
      class << self
        def instance(config: RubyLlmMesh.configuration, registry: nil)
          @instance ||= new(config: config, registry: registry)
        end

        def reset!
          @instance&.stop!
          @instance = nil
        end
      end

      def initialize(config: RubyLlmMesh.configuration, registry: nil)
        @config = config
        @registry = registry || PeerRegistry.instance(config: config)
        @mutex = Mutex.new
        @thread = nil
        @stopped = true
      end

      def check_all!
        @registry.all_urls.each { |url| check!(url) }
      end

      def check!(url)
        healthy = healthy?(url)
        if healthy
          @registry.mark_healthy(url)
        else
          @registry.mark_unhealthy(url, error: "health check failed")
        end
        healthy
      rescue StandardError => e
        @registry.mark_unhealthy(url, error: e.message)
        false
      end

      def healthy?(url)
        base = url.to_s.chomp("/")
        paths = [
          @config.peer_health_path,
          "/v1/models",
          "/api/tags"
        ].uniq

        paths.any? { |path| ping("#{base}#{path}") }
      end

      def start!
        return unless @config.peer_discovery_enabled
        return if @thread&.alive?

        @stopped = false
        interval = [@config.peer_health_interval, 1].max
        @thread = Thread.new do
          until @stopped
            begin
              check_all!
            rescue StandardError
              # keep looping
            end
            sleep interval
          end
        end
        @thread.abort_on_exception = false
        @thread
      end

      def stop!
        @stopped = true
        @thread&.kill
        @thread = nil
      end

      def running?
        !@stopped && @thread&.alive?
      end

      private

      def ping(url)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @config.peer_health_timeout
        http.read_timeout = @config.peer_health_timeout
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)
        response.code.to_i.between?(200, 299)
      rescue StandardError
        false
      end
    end
  end
end

# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module RubyLlmMesh
  module Providers
    class Base
      attr_reader :config

      def initialize(config = RubyLlmMesh.configuration)
        @config = config
      end

      def name
        raise NotImplementedError
      end

      def complete(prompt:, system: nil, model: nil, **options)
        raise NotImplementedError
      end

      protected

      def http_post(url, headers:, body:, timeout: nil)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout || config.timeout
        http.read_timeout = timeout || config.timeout

        request = Net::HTTP::Post.new(uri)
        headers.each { |k, v| request[k] = v }
        request.body = JSON.generate(body)

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = http.request(request)
        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

        [response, latency_ms]
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
        raise TimeoutError.new(e.message, provider: name)
      rescue SocketError, EOFError, IOError, OpenSSL::SSL::SSLError,
             Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
             Errno::ENETUNREACH, Errno::ETIMEDOUT, Errno::EPIPE => e
        # Wrap transport failures so the router can trip circuits / fall back
        raise ProviderError.new(e.message, provider: name)
      end

      def parse_json(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        { "raw" => response.body }
      end

      def raise_for_status!(response)
        code = response.code.to_i
        return if code.between?(200, 299)

        body = response.body
        message = "#{name} HTTP #{code}: #{body.to_s[0, 300]}"

        case code
        when 401, 403
          raise AuthenticationError.new(message, provider: name, status: code, body: body)
        when 429
          raise RateLimitError.new(message, provider: name, status: code, body: body)
        else
          raise ProviderError.new(message, provider: name, status: code, body: body)
        end
      end
    end
  end
end

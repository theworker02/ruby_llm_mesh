# frozen_string_literal: true

module RubyLlmMesh
  module Providers
    class Anthropic < Base
      def name
        :anthropic
      end

      def complete(prompt:, system: nil, model: nil, **options)
        api_key = config.anthropic_api_key
        raise AuthenticationError.new("ANTHROPIC_API_KEY is not configured", provider: name) if api_key.to_s.empty?

        model ||= config.anthropic_model
        body = {
          model: model,
          max_tokens: options.fetch(:max_tokens, 1024),
          messages: [{ role: "user", content: prompt }]
        }
        body[:system] = system if system
        body[:temperature] = options[:temperature] if options.key?(:temperature)
        body[:tools] = options[:tools] if options[:tools]

        response, latency_ms = http_post(
          "#{config.anthropic_base_url.chomp('/')}/v1/messages",
          headers: {
            "x-api-key" => api_key,
            "anthropic-version" => "2023-06-01",
            "Content-Type" => "application/json"
          },
          body: body
        )

        raise_for_status!(response)
        data = parse_json(response)
        content = Array(data["content"]).map { |block| block["text"] }.compact.join

        Response.new(
          content: content,
          provider: name,
          model: data["model"] || model,
          usage: data["usage"] || {},
          raw: data,
          latency_ms: latency_ms
        )
      end
    end
  end
end

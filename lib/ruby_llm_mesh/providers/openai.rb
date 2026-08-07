# frozen_string_literal: true

module RubyLlmMesh
  module Providers
    class Openai < Base
      def name
        :openai
      end

      def complete(prompt:, system: nil, model: nil, **options)
        api_key = config.openai_api_key
        raise AuthenticationError.new("OPENAI_API_KEY is not configured", provider: name) if api_key.to_s.empty?

        model ||= config.openai_model
        messages = []
        messages << { role: "system", content: system } if system
        messages << { role: "user", content: prompt }

        body = {
          model: model,
          messages: messages,
          temperature: options.fetch(:temperature, 0.7)
        }
        body[:max_tokens] = options[:max_tokens] if options[:max_tokens]
        body[:tools] = options[:tools] if options[:tools]

        response, latency_ms = http_post(
          "#{config.openai_base_url.chomp('/')}/chat/completions",
          headers: {
            "Authorization" => "Bearer #{api_key}",
            "Content-Type" => "application/json"
          },
          body: body
        )

        raise_for_status!(response)
        data = parse_json(response)
        choice = data.dig("choices", 0, "message", "content").to_s

        Response.new(
          content: choice,
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

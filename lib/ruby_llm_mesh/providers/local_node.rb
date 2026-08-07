# frozen_string_literal: true

module RubyLlmMesh
  module Providers
    # OpenAI-compatible local runtime (Ollama, LM Studio, vLLM, llama.cpp server, etc.)
    class LocalNode < Base
      def name
        :local_node
      end

      def complete(prompt:, system: nil, model: nil, **options)
        model ||= config.local_node_model
        messages = []
        messages << { role: "system", content: system } if system
        messages << { role: "user", content: prompt }

        body = {
          model: model,
          messages: messages,
          stream: false,
          temperature: options.fetch(:temperature, 0.7)
        }
        body[:options] = { num_predict: options[:max_tokens] } if options[:max_tokens]

        response, latency_ms = http_post(
          "#{config.local_node_base_url.chomp('/')}/v1/chat/completions",
          headers: { "Content-Type" => "application/json" },
          body: body
        )

        # Fallback to Ollama native chat API if OpenAI-compat endpoint is missing
        if response.code.to_i == 404
          response, latency_ms = http_post(
            "#{config.local_node_base_url.chomp('/')}/api/chat",
            headers: { "Content-Type" => "application/json" },
            body: { model: model, messages: messages, stream: false }
          )
          raise_for_status!(response)
          data = parse_json(response)
          content = data.dig("message", "content").to_s
          return Response.new(
            content: content,
            provider: name,
            model: model,
            usage: {},
            raw: data,
            latency_ms: latency_ms
          )
        end

        raise_for_status!(response)
        data = parse_json(response)
        content = data.dig("choices", 0, "message", "content").to_s

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

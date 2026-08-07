# frozen_string_literal: true

module RubyLlmMesh
  module Providers
    # OpenAI-compatible local runtime (Ollama, LM Studio, vLLM, llama.cpp server, etc.).
    # When peer discovery is enabled, tries healthy peers from Mesh::PeerRegistry.
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

        errors = []
        peer_bases.each do |base_url|
          begin
            return complete_against(base_url, model: model, body: body, messages: messages)
          rescue RateLimitError, TimeoutError, ProviderError => e
            registry.mark_unhealthy(base_url, error: e.message)
            errors << e
            next
          end
        end

        raise errors.last || ProviderError.new("No healthy local peers available", provider: name)
      end

      private

      def registry
        @registry ||= Mesh::PeerRegistry.instance(config: config)
      end

      def peer_bases
        urls = registry.healthy_urls
        urls = [config.local_node_base_url.to_s.chomp("/")] if urls.empty?
        urls
      end

      def complete_against(base_url, model:, body:, messages:)
        base = base_url.to_s.chomp("/")

        response, latency_ms = http_post(
          "#{base}/v1/chat/completions",
          headers: { "Content-Type" => "application/json" },
          body: body
        )

        # Fallback to Ollama native chat API if OpenAI-compat endpoint is missing
        if response.code.to_i == 404
          response, latency_ms = http_post(
            "#{base}/api/chat",
            headers: { "Content-Type" => "application/json" },
            body: { model: model, messages: messages, stream: false }
          )
          raise_for_status!(response)
          data = parse_json(response)
          content = data.dig("message", "content").to_s
          registry.mark_healthy(base)
          return Response.new(
            content: content,
            provider: name,
            model: model,
            usage: {},
            raw: data.merge("_peer" => base),
            latency_ms: latency_ms
          )
        end

        raise_for_status!(response)
        data = parse_json(response)
        content = data.dig("choices", 0, "message", "content").to_s
        registry.mark_healthy(base)

        Response.new(
          content: content,
          provider: name,
          model: data["model"] || model,
          usage: data["usage"] || {},
          raw: data.merge("_peer" => base),
          latency_ms: latency_ms
        )
      end
    end
  end
end

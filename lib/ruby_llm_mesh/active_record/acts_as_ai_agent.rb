# frozen_string_literal: true

module RubyLlmMesh
  module ActiveRecord
    # Optional Rails hooks for conversational memory, semantic caching, and audit logs.
    #
    #   class Conversation < ApplicationRecord
    #     acts_as_ai_agent
    #   end
    module ActsAsAiAgent
      def acts_as_ai_agent(memory_attribute: :messages, cache_attribute: :semantic_cache, audit_attribute: :ai_audits)
        class_attribute :ai_agent_memory_attribute, instance_writer: false
        class_attribute :ai_agent_cache_attribute, instance_writer: false
        class_attribute :ai_agent_audit_attribute, instance_writer: false

        self.ai_agent_memory_attribute = memory_attribute
        self.ai_agent_cache_attribute = cache_attribute
        self.ai_agent_audit_attribute = audit_attribute

        include InstanceMethods
      end

      module InstanceMethods
        def ai_complete(prompt, **options)
          cached = ai_semantic_lookup(prompt)
          return cached if cached

          memory = ai_memory
          system = options.delete(:system)
          system = [system, "Conversation memory:\n#{memory.join("\n")}"].compact.join("\n\n") unless memory.empty?

          response = RubyLlmMesh.complete(prompt: prompt, system: system, **options)
          ai_remember!(role: "user", content: prompt)
          ai_remember!(role: "assistant", content: response.content, provider: response.provider)
          ai_cache!(prompt, response)
          ai_audit!(prompt, response)
          response
        end

        def ai_memory
          raw = read_ai_json(self.class.ai_agent_memory_attribute)
          Array(raw)
        end

        def ai_remember!(entry)
          memory = ai_memory
          memory << entry.transform_keys(&:to_s)
          write_ai_json(self.class.ai_agent_memory_attribute, memory)
          save if respond_to?(:save)
        end

        def ai_clear_memory!
          write_ai_json(self.class.ai_agent_memory_attribute, [])
          save if respond_to?(:save)
        end

        def ai_semantic_lookup(prompt)
          cache = read_ai_json(self.class.ai_agent_cache_attribute)
          return nil unless cache.is_a?(Hash)

          entry = cache[prompt.to_s]
          return nil unless entry

          RubyLlmMesh::Response.new(
            content: entry["content"],
            provider: (entry["provider"] || :cache).to_sym,
            model: entry["model"],
            usage: entry["usage"] || {},
            latency_ms: 0,
            fallback_used: false
          )
        end

        def ai_cache!(prompt, response)
          cache = read_ai_json(self.class.ai_agent_cache_attribute)
          cache = {} unless cache.is_a?(Hash)
          cache[prompt.to_s] = {
            "content" => response.content,
            "provider" => response.provider.to_s,
            "model" => response.model,
            "usage" => response.usage
          }
          write_ai_json(self.class.ai_agent_cache_attribute, cache)
        end

        def ai_audit!(prompt, response)
          audits = read_ai_json(self.class.ai_agent_audit_attribute)
          audits = [] unless audits.is_a?(Array)
          audits << {
            "at" => Time.now.utc.iso8601,
            "prompt" => prompt.to_s,
            "provider" => response.provider.to_s,
            "model" => response.model,
            "latency_ms" => response.latency_ms,
            "fallback_used" => response.fallback_used
          }
          write_ai_json(self.class.ai_agent_audit_attribute, audits)
        end

        private

        def read_ai_json(attr)
          return [] unless respond_to?(attr)

          value = public_send(attr)
          return value if value.is_a?(Array) || value.is_a?(Hash)
          return JSON.parse(value) if value.is_a?(String) && !value.empty?

          value.nil? ? nil : value
        rescue JSON::ParserError
          nil
        end

        def write_ai_json(attr, value)
          return unless respond_to?("#{attr}=")

          public_send("#{attr}=", value)
        end
      end
    end
  end
end

if defined?(::ActiveRecord::Base)
  ::ActiveRecord::Base.extend(RubyLlmMesh::ActiveRecord::ActsAsAiAgent)
end

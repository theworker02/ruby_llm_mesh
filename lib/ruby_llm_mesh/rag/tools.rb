# frozen_string_literal: true

module RubyLlmMesh
  module Rag
    # Helpers for structuring tool / function-calling schemas across providers.
    module Tools
      module_function

      def define(name:, description:, parameters: {}, required: [])
        {
          name: name.to_s,
          description: description.to_s,
          parameters: {
            type: "object",
            properties: parameters,
            required: Array(required).map(&:to_s)
          }
        }
      end

      def for_openai(tools)
        Array(tools).map do |tool|
          {
            type: "function",
            function: {
              name: tool[:name] || tool["name"],
              description: tool[:description] || tool["description"],
              parameters: tool[:parameters] || tool["parameters"]
            }
          }
        end
      end

      def for_anthropic(tools)
        Array(tools).map do |tool|
          {
            name: tool[:name] || tool["name"],
            description: tool[:description] || tool["description"],
            input_schema: tool[:parameters] || tool["parameters"]
          }
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class ToolsTest < Minitest::Test
  def test_define_tool_schema
    tool = RubyLlmMesh::Rag::Tools.define(
      name: :lookup_order,
      description: "Fetch an order",
      parameters: { order_id: { type: "string" } },
      required: [:order_id]
    )

    assert_equal "lookup_order", tool[:name]
    assert_equal "object", tool[:parameters][:type]
    assert_equal ["order_id"], tool[:parameters][:required]
  end

  def test_for_openai
    tool = RubyLlmMesh::Rag::Tools.define(
      name: "ping",
      description: "Ping",
      parameters: {}
    )
    mapped = RubyLlmMesh::Rag::Tools.for_openai([tool])
    assert_equal "function", mapped.first[:type]
    assert_equal "ping", mapped.first[:function][:name]
  end

  def test_for_anthropic
    tool = RubyLlmMesh::Rag::Tools.define(
      name: "ping",
      description: "Ping",
      parameters: { type: "object", properties: {} }
    )
    mapped = RubyLlmMesh::Rag::Tools.for_anthropic([tool])
    assert_equal "ping", mapped.first[:name]
    assert mapped.first.key?(:input_schema)
  end
end

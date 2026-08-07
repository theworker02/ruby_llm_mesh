# frozen_string_literal: true

require_relative "test_helper"

class ProviderHttpTest < Minitest::Test
  def test_openai_success
    RubyLlmMesh.configure { |c| c.openai_api_key = "sk-test" }

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          model: "gpt-4o-mini",
          choices: [{ message: { content: "hi from openai" } }],
          usage: { total_tokens: 10 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    response = RubyLlmMesh::Providers::Openai.new.complete(prompt: "hello")
    assert_equal "hi from openai", response.content
    assert_equal :openai, response.provider
  end

  def test_openai_missing_key
    RubyLlmMesh.configure { |c| c.openai_api_key = nil }
    assert_raises(RubyLlmMesh::AuthenticationError) do
      RubyLlmMesh::Providers::Openai.new.complete(prompt: "hello")
    end
  end

  def test_anthropic_success
    RubyLlmMesh.configure { |c| c.anthropic_api_key = "ant-test" }

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(
        status: 200,
        body: {
          model: "claude-sonnet-4-5",
          content: [{ type: "text", text: "hi from claude" }],
          usage: {}
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    response = RubyLlmMesh::Providers::Anthropic.new.complete(prompt: "hello")
    assert_equal "hi from claude", response.content
    assert_equal :anthropic, response.provider
  end

  def test_local_node_openai_compat
    stub_request(:post, "http://127.0.0.1:11434/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          model: "llama3.2",
          choices: [{ message: { content: "local reply" } }]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    response = RubyLlmMesh::Providers::LocalNode.new.complete(prompt: "hello")
    assert_equal "local reply", response.content
    assert_equal :local_node, response.provider
  end
end

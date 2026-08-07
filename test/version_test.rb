# frozen_string_literal: true

require_relative "test_helper"

class VersionTest < Minitest::Test
  def test_version_string
    assert_match(/\A\d+\.\d+\.\d+\z/, RubyLlmMesh::VERSION)
    assert_equal "0.1.0", RubyLlmMesh::VERSION
  end

  def test_ai_agent_router_configure_delegates
    AiAgentRouter.configure { |c| c.timeout = 12 }
    assert_equal 12, AiAgentRouter.configuration.timeout
    assert_equal 12, RubyLlmMesh.configuration.timeout
  end
end

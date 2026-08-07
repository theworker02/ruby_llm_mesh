# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "webmock/minitest"
require "ruby_llm_mesh"

module TestHelper
  def stub_provider(name, content: "ok", fail_with: nil)
    klass = Class.new(RubyLlmMesh::Providers::Base) do
      define_method(:name) { name }
      define_method(:complete) do |**|
        raise fail_with if fail_with

        RubyLlmMesh::Response.new(content: content, provider: name, model: "test", latency_ms: 1)
      end
    end
    klass
  end
end

class Minitest::Test
  include TestHelper

  def setup
    RubyLlmMesh.reset_configuration!
    RubyLlmMesh::Router.reset_circuit_breaker!
    RubyLlmMesh::Cache::SemanticCache.reset!
    RubyLlmMesh::Mesh::PeerRegistry.reset!
    RubyLlmMesh::Mesh::HealthMonitor.reset!
    RubyLlmMesh::NativeCore.reset!
    WebMock.reset!
  end
end

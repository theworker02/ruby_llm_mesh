# frozen_string_literal: true

require_relative "test_helper"

class NativeCoreTest < Minitest::Test
  def setup
    super
    RubyLlmMesh::NativeCore.reset!
  end

  def teardown
    RubyLlmMesh::NativeCore.reset!
    super
  end

  def test_require_does_not_crash_without_native_lib
    assert_respond_to RubyLlmMesh::NativeCore, :start_node
    assert_respond_to RubyLlmMesh::NativeCore, :node_alive?
    assert_respond_to RubyLlmMesh::NativeCore, :execute_wasm_payload
  end

  def test_version_string
    version = RubyLlmMesh::NativeCore.version
    assert version.is_a?(String)
    refute_empty version
  end

  def test_optional_native_integration
    skip "cargo/native lib not available" unless native_lib_present?

    assert RubyLlmMesh::NativeCore.available? || RubyLlmMesh::NativeCore.start_node(42_340)
    RubyLlmMesh::NativeCore.start_node(42_340)
    # After start, either native or fallback is alive
    assert RubyLlmMesh::NativeCore.node_alive?
    payload = RubyLlmMesh::NativeCore.execute_wasm_payload("native integration")
    assert payload["ok"]
    assert payload["output"]
  end

  private

  def native_lib_present?
    root = File.expand_path("..", __dir__)
    basename = case RbConfig::CONFIG["host_os"]
               when /mswin|mingw|cygwin/i then "chimera_core.dll"
               when /darwin/i then "libchimera_core.dylib"
               else "libchimera_core.so"
               end
    [
      File.join(root, "ext/chimera_core/target/release", basename),
      File.join(root, "ext/chimera_core/target/debug", basename)
    ].any? { |p| File.exist?(p) }
  end
end

# frozen_string_literal: true

require "json"

module RubyLlmMesh
  # Soft-loaded FFI bridge to the `chimera_core` native library.
  # When the shared library is missing or `ffi` is unavailable, methods
  # degrade to pure-Ruby fallbacks instead of crashing on require.
  module NativeCore
    class << self
      def available?
        !!@native_loaded
      end

      def start_node(port = RubyLlmMesh.configuration.mesh_port)
        ensure_boot_attempted!
        if available?
          !!@lib.start_node(Integer(port))
        else
          Fallback.start_node(port)
        end
      end

      def stop_node
        ensure_boot_attempted!
        if available?
          !!@lib.stop_node
        else
          Fallback.stop_node
        end
      end

      def node_alive?
        ensure_boot_attempted!
        if available?
          !!@lib.node_alive
        else
          Fallback.node_alive?
        end
      end

      def execute_wasm_payload(intent)
        ensure_boot_attempted!
        intent = intent.to_s
        raw = if available?
                @lib.execute_wasm_payload_string(intent)
              else
                Fallback.execute_wasm_payload(intent)
              end
        parse_payload(raw)
      end

      def version
        ensure_boot_attempted!
        return @lib.chimera_core_version_string if available?

        "fallback-#{RubyLlmMesh::VERSION}"
      end

      def reset!
        stop_node if node_alive?
        @boot_attempted = false
        @native_loaded = false
        @lib = nil
        Fallback.reset!
      end

      private

      def ensure_boot_attempted!
        return if @boot_attempted

        @boot_attempted = true
        @native_loaded = try_load_native!
      end

      def try_load_native!
        begin
          require "ffi"
        rescue LoadError
          return false
        end

        path = shared_library_path
        return false unless path && File.exist?(path)

        lib = Module.new
        lib.extend(FFI::Library)
        lib.ffi_lib path
        lib.attach_function :start_node, [:uint16], :bool
        lib.attach_function :stop_node, [], :bool
        lib.attach_function :node_alive, [], :bool
        lib.attach_function :execute_wasm_payload, [:string], :pointer
        lib.attach_function :chimera_free_string, [:pointer], :void
        lib.attach_function :chimera_core_version, [], :pointer

        def lib.execute_wasm_payload_string(intent)
          ptr = execute_wasm_payload(intent)
          return "{\"ok\":false,\"error\":\"null pointer\"}" if ptr.null?

          str = ptr.read_string
          chimera_free_string(ptr)
          str
        end

        def lib.chimera_core_version_string
          ptr = chimera_core_version
          return "unknown" if ptr.null?

          str = ptr.read_string
          chimera_free_string(ptr)
          str
        end

        @lib = lib
        true
      rescue StandardError
        false
      end

      def shared_library_path
        root = File.expand_path("../..", __dir__)
        crate = File.join(root, "ext", "chimera_core")
        candidates = [
          ENV["CHIMERA_CORE_LIB"],
          File.join(crate, "target", "release", library_basename),
          File.join(crate, "target", "debug", library_basename),
          File.join(root, "lib", "ruby_llm_mesh", "native", library_basename)
        ].compact
        candidates.find { |p| File.exist?(p) }
      end

      def library_basename
        case RbConfig::CONFIG["host_os"]
        when /mswin|mingw|cygwin/i then "chimera_core.dll"
        when /darwin/i then "libchimera_core.dylib"
        else "libchimera_core.so"
        end
      end

      def parse_payload(raw)
        data = JSON.parse(raw.to_s)
        data.is_a?(Hash) ? data : { "ok" => true, "output" => raw.to_s, "raw" => data }
      rescue JSON::ParserError
        { "ok" => true, "output" => raw.to_s, "engine" => available? ? "chimera_core" : "ruby_fallback" }
      end
    end

    # Pure-Ruby stand-in when the native library is not compiled.
    module Fallback
      @alive = false
      @port = nil
      @mutex = Mutex.new

      class << self
        def start_node(port)
          @mutex.synchronize do
            @port = Integer(port)
            @alive = true
          end
          true
        end

        def stop_node
          @mutex.synchronize do
            @alive = false
            @port = nil
          end
          true
        end

        def node_alive?
          @mutex.synchronize { @alive }
        end

        def execute_wasm_payload(intent)
          port = @mutex.synchronize { @port }
          alive = @mutex.synchronize { @alive }
          JSON.generate(
            ok: true,
            engine: "ruby_fallback",
            mode: "pure_ruby",
            alive: alive,
            port: port,
            intent: intent.to_s,
            output: "Fallback mesh executed intent (#{intent.to_s[0, 64]})"
          )
        end

        def reset!
          @mutex.synchronize do
            @alive = false
            @port = nil
          end
        end
      end
    end
  end
end

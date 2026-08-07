# frozen_string_literal: true

require_relative "lib/ruby_llm_mesh/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm_mesh"
  spec.version = RubyLlmMesh::VERSION
  spec.authors = ["theworker02"]
  spec.email = ["theworker02@users.noreply.github.com"]

  spec.summary = "Sovereign multi-provider AI mesh with native FFI core, circuit-breaking, and cloud failover for Ruby & Rails"
  spec.description = <<~DESC
    ruby_llm_mesh (AiAgentRouter) is a Ruby gem that routes AI intents across a native
    chimera_core mesh (Rust FFI), OpenAI, Anthropic, and local node runtimes with
    automatic circuit-breaking, fallback ladders, optional semantic caching, peer health
    monitoring, lightweight RAG helpers, and optional ActiveRecord hooks.

    Gem name uses underscores (ruby_llm_mesh) to match the GitHub repository and
    RubyGems listing at https://rubygems.org/gems/ruby_llm_mesh.
  DESC
  spec.homepage = "https://github.com/theworker02/ruby_llm_mesh"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/theworker02/ruby_llm_mesh"
  spec.metadata["changelog_uri"] = "https://github.com/theworker02/ruby_llm_mesh/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://theworker02.github.io/ruby_llm_mesh/"
  spec.metadata["bug_tracker_uri"] = "https://github.com/theworker02/ruby_llm_mesh/issues"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.start_with?(*%w[test/ spec/ features/ .git .github docs/]) ||
        f.end_with?(".gem") ||
        f.include?("/target/")
    end
  end
  if spec.files.empty?
    spec.files = Dir[
      "lib/**/*",
      "ext/**/*",
      "sig/**/*",
      "exe/**/*",
      "assets/**/*",
      "LICENSE*",
      "README*",
      "CHANGELOG*",
      "CODE_OF_CONDUCT*",
      "PRIVACY*",
      "CONTRIBUTING*",
      "*.gemspec",
      "Rakefile"
    ].reject { |f| f.include?("/target/") || f.end_with?(".gem") }
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Optional native compile — documented via `rake compile`; gem works without it.
  # spec.extensions = []  # cargo-based; use rake compile instead of mkmf

  spec.add_dependency "ffi", "~> 1.17"

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "webmock", "~> 3.24"
end

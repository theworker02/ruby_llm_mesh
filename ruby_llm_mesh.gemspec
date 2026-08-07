# frozen_string_literal: true

require_relative "lib/ruby_llm_mesh/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm_mesh"
  spec.version = RubyLlmMesh::VERSION
  spec.authors = ["theworker02"]
  spec.email = ["theworker02@users.noreply.github.com"]

  spec.summary = "Unified multi-provider AI routing with circuit-breaking and local fallback for Ruby & Rails"
  spec.description = <<~DESC
    ruby_llm_mesh (AiAgentRouter) is a drop-in Ruby gem that routes AI prompts across
    OpenAI, Anthropic, and local node runtimes with automatic circuit-breaking,
    fallback ladders, lightweight RAG helpers, and optional ActiveRecord hooks.
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
        f.end_with?(".gem")
    end
  end
  # Ensure packaging works before the first commit
  if spec.files.empty?
    spec.files = Dir[
      "lib/**/*",
      "sig/**/*",
      "exe/**/*",
      "assets/**/*",
      "LICENSE*",
      "README*",
      "CHANGELOG*",
      "CODE_OF_CONDUCT*",
      "*.gemspec"
    ]
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "webmock", "~> 3.24"
end

# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = true
end

desc "Compile chimera_core native library (requires Rust/cargo)"
task :compile do
  crate = File.expand_path("ext/chimera_core", __dir__)
  unless system("cargo", "--version", out: File::NULL, err: File::NULL)
    abort "cargo not found — install Rust from https://rustup.rs to compile chimera_core"
  end
  Dir.chdir(crate) do
    sh "cargo", "build", "--release"
  end
  puts "chimera_core built under ext/chimera_core/target/release/"
end

desc "Compile chimera_core in debug mode"
task "compile:debug" do
  crate = File.expand_path("ext/chimera_core", __dir__)
  Dir.chdir(crate) do
    sh "cargo", "build"
  end
end

desc "Run Rust unit tests for chimera_core"
task "test:native" do
  crate = File.expand_path("ext/chimera_core", __dir__)
  Dir.chdir(crate) do
    sh "cargo", "test"
  end
end

task default: :test

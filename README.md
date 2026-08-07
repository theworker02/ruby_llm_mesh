<p align="center">
  <img src="assets/logo.png" alt="ruby_llm_mesh logo" width="160" />
</p>

<h1 align="center">ruby_llm_mesh</h1>

<p align="center">
  Sovereign multi-provider AI mesh for Ruby &amp; Rails<br/>
  <code>AiAgentRouter</code> · native FFI core · circuit breaking · cloud failover
</p>

<p align="center">
  <a href="https://rubygems.org/gems/ruby_llm_mesh"><img src="https://img.shields.io/gem/v/ruby_llm_mesh?color=9B1B30" alt="Gem Version" /></a>
  <a href="https://github.com/theworker02/ruby_llm_mesh/actions/workflows/ci.yml"><img src="https://img.shields.io/badge/CI-GitHub%20Actions-1A1A1A" alt="CI" /></a>
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-E85D4C" alt="License: MIT" /></a>
  <a href="https://theworker02.github.io/ruby_llm_mesh/"><img src="https://img.shields.io/badge/docs-GitHub%20Pages-1A1A1A" alt="GitHub Pages" /></a>
</p>

<p align="center">
  <strong>Install from RubyGems:</strong>
  <a href="https://rubygems.org/gems/ruby_llm_mesh">https://rubygems.org/gems/ruby_llm_mesh</a>
</p>

> **Gem name:** `ruby_llm_mesh` (underscores) — matches this GitHub repo and the official RubyGems listing. Do not confuse with hyphenated names in design sketches.

## What it does (v2.0.0)

`ruby_llm_mesh` routes intents across:

1. A **native sovereign mesh** (`chimera_core` Rust cdylib via FFI) for local P2P-style execution
2. **Real cloud / local LLM HTTP** — OpenAI, Anthropic, and OpenAI-compatible nodes (Ollama, LM Studio, …)

When the native library is not compiled, a pure-Ruby fallback keeps the API working. Circuit breaking, optional semantic cache, peer health for multi-node local meshes, RAG helpers, and Rails hooks remain available.

## Install

```bash
gem install ruby_llm_mesh
```

Or in a Gemfile:

```ruby
gem "ruby_llm_mesh"
```

Then `bundle install`.

Gem page: [rubygems.org/gems/ruby_llm_mesh](https://rubygems.org/gems/ruby_llm_mesh)

### Compile the native core (optional)

Requires [Rust](https://rustup.rs) / `cargo`:

```bash
bundle exec rake compile
# → ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll)
```

Without compile, `NativeCore` uses an in-process Ruby fallback. `require "ruby_llm_mesh"` never crashes on a missing `.so`.

## Quickstart

```ruby
require "ruby_llm_mesh"

AiAgentRouter.configure do |c|
  c.openai_api_key = ENV["OPENAI_API_KEY"]
  c.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  c.mesh_port = 4233
  c.auto_boot_mesh = true
  c.fallback_providers = %i[openai anthropic local_node]
end

# Strategy-based execution (v2)
response = AiAgentRouter.execute(
  intent: "Summarize circuit breakers in one sentence.",
  strategy: :auto # :p2p_mesh | :cloud | :openai | :anthropic | :local_node
)
puts response.content
puts response.provider # => :p2p_mesh or a cloud provider

# Classic complete API (unchanged shape from 0.1.x)
response = AiAgentRouter.complete(
  prompt: "Hello from the mesh",
  providers: %i[anthropic openai local_node],
  fallback: true
)
```

## Strategies (`execute`)

| Strategy | Behavior |
|----------|----------|
| `:auto` | Boot native mesh if `auto_boot_mesh`; use P2P when alive, else real cloud ladder |
| `:p2p_mesh` | Native `chimera_core` (or Ruby fallback) only |
| `:cloud` | HTTP via `fallback_providers` / `default_providers` |
| `:openai` / `:anthropic` / `:local_node` / `:local_mesh` | Single-provider routing |

Cloud paths call the real provider HTTP clients — they are **not** stubbed simulation strings.

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `mesh_port` | `4233` | Native mesh listen port |
| `auto_boot_mesh` | `true` | Auto-start node for `:auto` / `:p2p_mesh` |
| `fallback_providers` | `%i[openai anthropic local_node]` | Ladder for `:cloud` / `:auto` failover |
| `default_providers` | `%i[openai anthropic local_node]` | Ladder for `complete` |
| `fallback` | `true` | Continue to next provider on failure |
| `timeout` | `30` | HTTP open/read timeout (seconds) |
| `openai_*` / `anthropic_*` / `local_node_*` | env-backed | Provider credentials & endpoints |
| `circuit_failure_threshold` / `circuit_reset_timeout` | `3` / `60` | Circuit breaker |
| `semantic_cache_enabled` | `false` | Opt-in vector similarity cache |
| `semantic_cache_threshold` / `semantic_cache_ttl` | `0.92` / `3600` | Cache match & TTL |
| `redis_url` | `ENV["REDIS_URL"]` | Optional Redis for distributed cache |
| `peer_discovery_enabled` / `peer_urls` | off / `[]` | Multi-peer local node health |
| `logger` | `nil` | `#info` / `#warn` / `#error` or `#call` |

## Native FFI surface

| C export | Ruby |
|----------|------|
| `start_node(port)` | `RubyLlmMesh.boot_mesh!` / `NativeCore.start_node` |
| `node_alive()` | `RubyLlmMesh.mesh_alive?` / `NativeCore.node_alive?` |
| `execute_wasm_payload(intent)` | `NativeCore.execute_wasm_payload` → Hash |
| `stop_node()` | `NativeCore.stop_node` |

## Circuit breaker & providers

Same as 0.1.x: per-provider circuits, fallback ladders, `AllProvidersFailedError`. Providers: `:openai`, `:anthropic`, `:local_node` (alias `:local_mesh` for peer-aware local routing).

## RAG helpers

```ruby
chunks = RubyLlmMesh::Rag::Chunker.new(size: 500, overlap: 50).chunk(long_text)
embedder = RubyLlmMesh::Rag::Embeddings.new(dimensions: 256)
hits = embedder.top_k("billing refunds", documents, k: 3)
```

## Rails: `acts_as_ai_agent`

```ruby
class Conversation < ApplicationRecord
  acts_as_ai_agent
end
```

## Upgrading from 0.1.0 → 2.0.0

- Bump the gem to `2.0.0` (`~> 0.1` will not pick this up).
- `complete` / `AiAgentRouter.complete` remain; prefer `execute` for mesh strategies.
- Install `ffi` (declared dependency). Compile native core only if you want the Rust engine.
- If you configured RubyGems trusted publishing against `push_gem.yml`, update the workflow filename to **`release.yml`**.

## Development

```bash
bundle install
bundle exec rake test          # no Rust required
bundle exec rake compile       # optional native build
bundle exec rake test:native   # cargo test
```

## Trusted publishing (RubyGems)

Releases publish via [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/) using `.github/workflows/release.yml` on tags matching `v*`.

| Field | Value |
|-------|-------|
| Gem name | `ruby_llm_mesh` |
| GitHub repository owner | `theworker02` |
| GitHub repository name | `ruby_llm_mesh` |
| Workflow filename | `release.yml` |
| Environment name | `release` |

Create a GitHub Environment named `release`. Pushing tag `v2.0.0` runs OIDC publish via `rubygems/release-gem@v1`.

## Branding

| Token | Hex |
|-------|-----|
| Ruby | `#9B1B30` |
| Coral | `#E85D4C` |
| Charcoal | `#1A1A1A` |

Docs: [https://theworker02.github.io/ruby_llm_mesh/](https://theworker02.github.io/ruby_llm_mesh/)

## Built with

Designed with [Cursor](https://cursor.com) models Opus and Fable 5.

## License

MIT — see [LICENSE.txt](LICENSE.txt).

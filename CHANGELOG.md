# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Full Contributor Covenant 2.1 [Code of Conduct](CODE_OF_CONDUCT.md) with enforcement guidelines
- [Privacy Policy](PRIVACY.md) for the OSS LLM routing gem (no phone-home; data stays with configured endpoints)
- README, CONTRIBUTING, and docs site links to Code of Conduct and Privacy Policy

### Fixed

- Router now honors `fallback: false` when a provider circuit is open or the provider name is unknown (no longer silently continues the ladder)
- `PeerRegistry#healthy_urls` no longer reintroduces unhealthy peers when the healthy set is empty (LocalNode uses its primary URL as last resort)
- Circuit breaker half-open state allows a single probe (not unbounded concurrent probes)
- HTTP client wraps connection reset / SSL / EOF transport errors as `ProviderError` so failover works
- Redis semantic-cache index cleans up stale entry IDs after TTL expiry

## [2.0.0] - 2026-08-07

### Added

- **Sovereign Mesh Core** — optional Rust `chimera_core` cdylib under `ext/chimera_core/` with FFI exports `start_node`, `node_alive`, `execute_wasm_payload`, `stop_node`
- **`RubyLlmMesh.execute` / `AiAgentRouter.execute`** — strategy-based intent execution (`:auto`, `:p2p_mesh`, `:cloud`, `:openai`, `:anthropic`, `:local_node`, `:local_mesh`)
- Pure-Ruby **NativeCore fallback** when the shared library or `ffi` load fails (require never hard-crashes)
- Mesh config: `mesh_port` (default `4233`), `auto_boot_mesh`, `fallback_providers`
- Optional **semantic cache** (in-memory or Redis when `REDIS_URL` + `redis` gem present)
- Optional **peer health monitoring** for multi-URL local node meshes (`peer_urls`, `HealthMonitor`)
- `rake compile` to build chimera_core via cargo
- Trusted publishing workflow `.github/workflows/release.yml` (OIDC + GitHub Release)

### Changed

- Version jump to **2.0.0** (Sovereign Mesh / FFI major)
- Gem dependency: `ffi ~> 1.17`
- Cloud failover remains real HTTP (OpenAI / Anthropic / local_node) — not stubbed

### Breaking

- Major version bump; consumers pinning `~> 0.1` must opt into `2.0.0`
- New default mesh settings (`auto_boot_mesh: true`, `mesh_port: 4233`) affect `:auto` / `:p2p_mesh` strategies only — `complete` API behavior is unchanged when semantic cache stays off (default)
- Trusted publisher workflow filename is now **`release.yml`** (was `push_gem.yml`)

## [0.1.0] - 2026-08-07

### Added

- Unified multi-provider routing via `RubyLlmMesh.complete` / `AiAgentRouter.complete`
- Providers: OpenAI, Anthropic, and OpenAI-compatible local nodes (Ollama, LM Studio, vLLM, etc.)
- Per-provider circuit breaker with configurable failure threshold and reset timeout
- Automatic fallback across a provider ladder
- RAG helpers: text chunker, bag-of-words embeddings, tool schema adapters
- Optional ActiveRecord `acts_as_ai_agent` for memory, semantic cache, and audit logging
- Rails railtie that loads only when Rails is present
- Documentation site on GitHub Pages
- Trusted publishing workflow for RubyGems OIDC releases

[2.0.0]: https://github.com/theworker02/ruby_llm_mesh/releases/tag/v2.0.0
[0.1.0]: https://github.com/theworker02/ruby_llm_mesh/releases/tag/v0.1.0

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-07

### Added

- Unified multi-provider routing via `RubyLlmMesh.complete` / `AiAgentRouter.complete`
- Providers: OpenAI, Anthropic, and OpenAI-compatible local nodes (Ollama, LM Studio, vLLM, etc.)
- Per-provider circuit breaker with configurable failure threshold and reset timeout
- Automatic fallback across a provider ladder
- RAG helpers: text chunker, bag-of-words embeddings, tool schema adapters
- Optional ActiveRecord `acts_as_ai_agent` for memory, semantic cache, and audit logging
- Rails railtie that loads only when Rails is present

[0.1.0]: https://github.com/theworker02/ruby_llm_mesh/releases/tag/v0.1.0

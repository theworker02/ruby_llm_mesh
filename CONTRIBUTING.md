# Contributing to ruby_llm_mesh

Thanks for your interest in improving this gem.

## Development setup

```bash
git clone https://github.com/theworker02/ruby_llm_mesh.git
cd ruby_llm_mesh
bundle install
bundle exec rake test
```

## Guidelines

1. Open an issue before large API changes.
2. Prefer focused pull requests with tests for new behavior.
3. Keep the public DSL (`AiAgentRouter` / `RubyLlmMesh`) stable unless a major version bump is intentional.
4. Do not commit API keys, credentials, or local `.env` files.
5. Follow the existing code style (frozen string literals, clear error types).

## Testing

Unit tests must not require live provider credentials. Stub HTTP with WebMock or inject stub providers.
Native FFI tests skip automatically when `chimera_core` is not compiled.

```bash
bundle exec rake test
bundle exec rake compile   # optional — requires Rust/cargo
```

## Releases

Maintainers cut releases by tagging `vX.Y.Z` on `main`, which triggers the
RubyGems Trusted Publisher workflow (`.github/workflows/release.yml`).

See the README for Trusted Publisher setup details.

## Code of Conduct

By participating, you agree to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

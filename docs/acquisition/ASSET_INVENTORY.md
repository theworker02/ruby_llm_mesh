# Asset inventory â€” Ã¢â€ â€™ ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll)

## Repository surfaces

| Asset | Location / notes |
|-------|------------------|
| Source tree | Repository root / language packages |
| Tests | `test/`, `tests/`, CI workflows if present |
| Docs | `README.md`, `docs/` |
| Diligence room | `docs/acquisition/` |
| License / notices | `LICENSE`, transition notices if present |
| Funding | `.github/FUNDING.yml` |
| CI | `.github/workflows/` if present |
| Branding | logos/assets folders if present |

## Capability highlights

- Bump the gem to `2.0.0` (`~> 0.1` will not pick this up).
- `complete` / `AiAgentRouter.complete` remain; prefer `execute` for mesh strategies.
- Install `ffi` (declared dependency). Compile native core only if you want the Rust engine.
- If you configured RubyGems trusted publishing against `push_gem.yml`, update the workflow filename to **`release.yml`**.
- Bump to [2.2.0 on RubyGems](https://rubygems.org/gems/ruby_llm_mesh/versions/2.2.0).
- Transient provider failures now retry with exponential backoff (`max_retries`, `retry_backoff`) before failover. Authentication failures still skip retries.
- [Code of Conduct](CODE_OF_CONDUCT.md) Ã¢â‚¬â€ Contributor Covenant 2.1; see also [CONTRIBUTING.md](CONTRIBUTING.md)
- [Privacy Policy](PRIVACY.md) Ã¢â‚¬â€ no phone-home telemetry; prompts and API keys stay with endpoints you configure

## Usually excluded

Seller personal accounts, unrelated repos, and unreissued registry tokens â€” unless listed in the definitive agreement.

*Updated: 2026-09-22*

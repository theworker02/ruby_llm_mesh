# Acquisition Brief â€” Ã¢â€ â€™ ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll)

**Date:** 2026-09-22  
**Repository:** https://github.com/theworker02/ruby_llm_mesh  
**Default branch:** `main`  
**Primary language:** Ruby  
**Status:** Diligence briefing only. **No acquisition has occurred** by virtue of this file.  
**License:** Proprietary â€” sale, written commercial license, or completed asset transfer required (see root `LICENSE`).  
**Valuation:** Not stated.  
**Contact:** GitHub [@theworker02](https://github.com/theworker02) Â· [thanks.dev/u/gh/theworker02](https://thanks.dev/u/gh/theworker02)

> Cloning or forking this repository does **not** grant production, redistribution, SaaS, OEM, or commercial rights.

---

## 1. Executive thesis

<img src="assets/logo.png" alt="ruby_llm_mesh logo" width="160" /> Sovereign multi-provider AI mesh for Ruby &amp; Rails<br/> <code>AiAgentRouter</code> Ã‚Â· native FFI core Ã‚Â· circuit breaking Ã‚Â· cloud failover

**Why a buyer cares:** Ã¢â€ â€™ ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll) packages transferable product IP â€” source, docs, in-repo brand assets, and a diligence room under `docs/acquisition/` â€” under a clear proprietary posture so diligence can proceed without mistaking the repo for open source.

---

## 2. Product snapshot

| Item | Detail |
|------|--------|
| Product | Ã¢â€ â€™ ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll) |
| Repo | `theworker02/ruby_llm_mesh` |
| Language | Ruby |
| Open source? | **No** â€” proprietary |
| Rightsholder | theworker02 |
| Diligence pack | `docs/acquisition/` |

### Capability highlights (from current materials)

- Bump the gem to `2.0.0` (`~> 0.1` will not pick this up).
- `complete` / `AiAgentRouter.complete` remain; prefer `execute` for mesh strategies.
- Install `ffi` (declared dependency). Compile native core only if you want the Rust engine.
- If you configured RubyGems trusted publishing against `push_gem.yml`, update the workflow filename to **`release.yml`**.
- Bump to [2.2.0 on RubyGems](https://rubygems.org/gems/ruby_llm_mesh/versions/2.2.0).
- Transient provider failures now retry with exponential backoff (`max_retries`, `retry_backoff`) before failover. Authentication failures still skip retries.
- [Code of Conduct](CODE_OF_CONDUCT.md) Ã¢â‚¬â€ Contributor Covenant 2.1; see also [CONTRIBUTING.md](CONTRIBUTING.md)
- [Privacy Policy](PRIVACY.md) Ã¢â‚¬â€ no phone-home telemetry; prompts and API keys stay with endpoints you configure

---

## 3. Problem / opportunity

Teams evaluating Ã¢â€ â€™ ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll) typically need either (a) a commercial right to run or embed it, or (b) outright ownership of the Product IP for strategic build-out. Public GitHub visibility without a proprietary license creates false assumptions about free production use. This brief and the linked data room make the commercial path explicit.

---

## 4. What ships today

Honest maturity: treat repository contents, README claims, tests, and release tags as the source of truth. Do not assume production customers, ARR, filed patents, or SLAs unless separately evidenced in diligence.

Typical transferable surfaces:

- Source tree and build/test scripts present in-repo
- Documentation and design notes
- Acquisition / diligence markdown under `docs/acquisition/`
- Branding assets committed to the repository (if any)

---

## 5. Demo / evaluation path (buyer)

Minimal path (no secrets required unless README says otherwise):

```
```bash
gem install ruby_llm_mesh
```
```ruby
gem "ruby_llm_mesh"
```
```bash
bundle exec rake compile
# Ã¢â€ â€™ ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll)
```
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
```ruby
chunks = RubyLlmMesh::Rag::Chunker.new(size: 500, overlap: 50).chunk(long_text)
embedder = RubyLlmMesh::Rag::Embeddings.new(dimensions: 256)
hits = embedder.top_k("billing refunds", documents, k: 3)
```

Extended evaluation: `docs/acquisition/BUYER_EVALUATION.md`. Written NDA / evaluation grants may be required for private materials.

---

## 6. What a transaction typically includes

Subject to definitive schedules:

| Included (typical) | Excluded (typical) |
|--------------------|--------------------|
| Repo materials + asserted original IP | Seller personal accounts / unrelated repos |
| Docs + diligence room at closing | Third-party dependency source under separate licenses |
| In-repo brand marks as assigned | Secrets without rotation plan |
| Know-how captured in docs | Fabricated revenue, user, or adoption metrics |

---

## 7. Suggested deal structures

| Structure | When it fits |
|-----------|--------------|
| Non-exclusive commercial license | Deploy/run under seat or environment terms |
| Exclusive field-of-use license | Buyer wants exclusivity; seller may retain entity |
| Asset / IP assignment | Buyer wants ownership of Materials outright |
| OEM / redistribution | Separate agreement â€” not implied here |

Commercial terms (price, earnouts, escrow) are negotiated under NDA with counsel.

---

## 8. Buyer diligence checklist

- [ ] Confirm Rightsholder identity and authority to sell/license
- [ ] Inventory Materials (`docs/acquisition/ASSET_INVENTORY.md`)
- [ ] Review IP posture (`IP_PROVENANCE.md`) and dependencies (`DEPENDENCY_INVENTORY.md`)
- [ ] Run evaluation script (`BUYER_EVALUATION.md`)
- [ ] Review risks (`RISK_REGISTER.md`)
- [ ] Agree transfer scope (`TRANSFER_MANIFEST.md`) and handoff (`HANDOFF_CHECKLIST.md`)
- [ ] Supersede root `LICENSE` at closing via definitive agreement

---

## 9. Related documents

| Document | Purpose |
|----------|---------|
| `LICENSE` | Proprietary â€” no default grant |
| `docs/acquisition/README.md` | Data-room index |
| `docs/acquisition/EXECUTIVE_SUMMARY.md` | One-page thesis |
| `README.md` | Product overview |
| `SECURITY.md` | Vulnerability reporting |
| `COMMERCIAL.md` | Licensing contact path |
| `.github/FUNDING.yml` | Sponsors / thanks.dev |

---

## 10. Disclaimer

This package is informational and **does not** create a binding offer, grant of rights, or investment advice. Engage counsel for any transaction.

---

*Document version: 2.0.0 / 2026-09-22 Â· Classification: acquisition briefing*

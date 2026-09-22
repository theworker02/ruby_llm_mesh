# Buyer evaluation â€” Ã¢â€ â€™ ext/chimera_core/target/release/libchimera_core.so (or .dylib / .dll)

## Goal

In 15â€“45 minutes, verify the Product builds or runs as documented and that proprietary notices are present.

## Steps

1. Confirm root `LICENSE` is proprietary and `ACQUISITION.md` exists.
2. Skim `README.md` install/run claims.
3. Execute:

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

4. Run tests if present (`npm test`, `pytest`, `cargo test`, `go test ./...`, etc.).
5. Record README vs observed behavior gaps in workpapers.

## Pass criteria

- [ ] Clone succeeds
- [ ] Documented happy path works **or** failure is explained
- [ ] Minimal path needs no surprise secrets
- [ ] License notices intact

*Updated: 2026-09-22*

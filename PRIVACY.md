# Privacy Policy

**Effective date:** 2026-08-07  
**Applies to:** the open-source `ruby_llm_mesh` Ruby gem and its companion documentation at [github.com/theworker02/ruby_llm_mesh](https://github.com/theworker02/ruby_llm_mesh)

## Summary

`ruby_llm_mesh` is a **library you run in your own Ruby/Rails process**. The maintainers of this project do **not** operate a hosted routing service, do **not** receive your prompts by default, and do **not** collect telemetry, analytics, or crash reports from gem usage.

## What this gem does with data

When you call APIs such as `AiAgentRouter.execute` / `RubyLlmMesh.complete`, the gem may:

1. **Send prompts and related options** to LLM HTTP endpoints **you configure** (for example OpenAI, Anthropic, or a local OpenAI-compatible node such as Ollama / LM Studio), using API keys and base URLs from your environment or configuration.
2. **Run intents through the optional native mesh / pure-Ruby fallback** entirely **inside your process** (and any peers **you** configure).
3. **Optionally store prompt/response material** in an in-process or Redis semantic cache **only if you enable** semantic caching and point it at infrastructure you control.
4. **Optionally record conversational memory / audits** when you use Rails `acts_as_ai_agent` helpers — that data lives in **your** database attributes.

The gem does not phone home to the `ruby_llm_mesh` authors.

## What we do not collect

- No usage analytics or phone-home telemetry from the gem
- No automatic upload of prompts, completions, embeddings, or API keys to project maintainers
- No account system or user database operated by this project for gem runtime traffic

## Third-party providers

If you configure cloud providers, **those providers’ privacy policies apply** to data you send them (prompts, system messages, tools, etc.). Review and configure:

- [OpenAI Privacy](https://openai.com/policies/privacy-policy/) (or your compatible endpoint’s policy)
- [Anthropic Privacy](https://www.anthropic.com/legal/privacy) (or your configured Anthropic-compatible endpoint)

Local nodes and peer URLs you list are under **your** operational control and policies.

## Credentials and secrets

API keys (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, Redis URLs, etc.) are read from your environment or configuration and used only to talk to endpoints you choose. Do not commit secrets to git. This repository’s tests are designed to run **without** live credentials.

## GitHub / project website

Visiting the GitHub repository, Issues, Discussions, or GitHub Pages docs is subject to [GitHub’s Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement). Maintainers may see information you voluntarily provide in issues, PRs, or emails (for example contact details in a Code of Conduct report).

## Children

This project is a developer library and is not directed at children.

## Changes

Privacy practices for the gem may change as the project evolves. Material updates will be reflected in this file in the repository. Continued use of a newer gem version after an update constitutes awareness of the revised policy for that version’s documented behavior.

## Contact

Privacy questions about **this open-source project** (not about third-party LLM vendors): open a GitHub issue in [theworker02/ruby_llm_mesh](https://github.com/theworker02/ruby_llm_mesh/issues) or contact the maintainers via the repository.

For Code of Conduct enforcement, see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

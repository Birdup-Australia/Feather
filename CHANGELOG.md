# Changelog

## 0.5.0 - 2026-10-02

- **Breaking:** requires `ruby_llm` 2.x (fixes the ReDoS advisory in 1.x). Dev dependencies updated to clear all `bundle-audit` findings (rubocop no longer pulls in `mcp`).
- `Result#cost` now comes from RubyLLM's per-model pricing registry instead of a hardcoded Anthropic-only table, so Haiku and non-Anthropic models are priced correctly; `nil` when the registry has no price.
- `config.provider` is now a no-op kept for compatibility; RubyLLM 2 resolves the provider from the model.
- Fix: `media_resolution` (a Gemini `generationConfig` field) is only sent to Gemini models. It was previously sent to every provider, which Anthropic rejects.
- Fix: audio transcripts are now interpolated as text; previously the `RubyLLM::Transcription` object was interpolated.

## 0.4.0 - 2026-07-05

- Identification now returns ranked `candidates` (up to 3, each `{common_name:, species:, score:}`) on every `Result`, populated straight from the structured-output schema.
- New `tools:` keyword on `FeatherAi.identify` (and `FeatherAi.configure { |c| c.tools = [...] }`) forwards RubyLLM tools to the chat, so identification can ground itself in real data (e.g. a species/region lookup backed by your app's database).
- **Breaking:** consensus disagreement `candidates` changed from an array of `Result` objects to the same ranked-hash shape, scored by vote share.
- `acts_as_sighting`'s `identify!` persists `candidates` when the table has a `candidates` column (new migrations add it as `jsonb`); existing tables without the column are unaffected.
- Default models bumped to `claude-sonnet-4-5` / `claude-haiku-4-5` (Anthropic structured outputs require Sonnet 4.5+; the old `claude-haiku-4` id no longer resolves).

Note: on Gemini models, combining a response schema with tools is rejected by the API on many models — the `tools:` option is tested against the Anthropic defaults.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

FeatherAi is a Ruby gem for identifying birds from photos and audio using RubyLLM. It adds multi-modal identification, location-aware results, multi-model consensus, and a Rails integration on top of RubyLLM.

## Commands

```bash
# Install dependencies
bin/setup

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/feather_ai/identifier_spec.rb

# Run a single example by line number
bundle exec rspec spec/feather_ai/identifier_spec.rb:15

# Lint
bundle exec rubocop

# Lint with auto-fix
bundle exec rubocop -A

# Run tests + lint (default rake task, same as CI)
bundle exec rake

# Interactive console with gem loaded
bin/console

# Build and install locally
bundle exec rake install

# Release (tags, pushes, publishes to RubyGems)
bundle exec rake release
```

## Architecture

The gem's only runtime dependency is `ruby_llm` (which pulls in `ruby_llm-schema`). All classes live under the `FeatherAi` module in `lib/feather_ai/`.

### Data Flow

`FeatherAi.identify(image, audio, location:, consensus:)` is the top-level entry point defined in `lib/feather_ai.rb`. `image` accepts a single path or an array of paths (multiple angles of the same bird). It delegates to:

1. **Identifier** (`lib/feather_ai/identifier.rb`) — Core identification logic. Uses RubyLLM's vision for images and `RubyLLM.transcribe` for audio. When both inputs are provided, they're combined into a single multi-modal prompt. Uses `RubyLLM::Schema` for structured output (including a `reasoning` field that forces step-by-step visual analysis before the identification). Also computes a USD cost estimate from token counts via the hardcoded `PROVIDER_RATES` table.

2. **Consensus** (`lib/feather_ai/consensus.rb`) — When `consensus: true`, runs identification through the configured `consensus_models` in parallel threads. Agreement is compared on normalized species name. If they agree, returns `confident: true`; if they disagree, returns both as `candidates` with low confidence. Token counts, cost, and duration are summed across models.

3. **Result** (`lib/feather_ai/result.rb`) — Immutable value object wrapping all identification output. Identification fields: `common_name`, `species`, `family`, `confidence` (`:high`/`:medium`/`:low`), `confident?`, `region_native?`, `reasoning`, `candidates`, `photography_tips`, `to_h`. Observability fields from the LLM call: `model_id`, `input_tokens`, `output_tokens`, `cost`, `duration_ms`, `source` (`:vision`/`:audio`/`:multimodal`), `consensus_models`. Photography tips are lazy-loaded via a second cheap LLM call only when accessed.

4. **PhotographyTips** (`lib/feather_ai/photography_tips.rb`) — Separate LLM call (uses `tips_model`, a small model) returning structured shooting advice for the identified species. Only invoked when `result.photography_tips` is called.

### Instrumentation

`Instrumentation.instrument` (`lib/feather_ai/instrumentation.rb`) wraps identification in `ActiveSupport::Notifications` when ActiveSupport is loaded, and is a plain `yield` otherwise. Events: `identify.feather_ai` (Identifier) and `consensus.feather_ai` (Consensus); the `Result` is added to the payload after the call completes.

### Errors

All errors inherit from `FeatherAi::Error`: `ConfigurationError` (e.g. no image or audio provided) and `IdentificationError` (LLM call failure).

### Configuration

```ruby
FeatherAi.configure do |c|
  c.provider         = :anthropic                             # default
  c.model            = "claude-sonnet-4"                      # default
  c.location         = "Perth, Western Australia"             # biases results to local species
  c.consensus_models = ["claude-sonnet-4", "claude-haiku-4"]  # default
  c.tips_model       = "claude-haiku-4"                       # default
  c.media_resolution = :high                                  # default; image resolution sent to provider
end
```

`FeatherAi.configuration` is a lazily-initialized process singleton; `FeatherAi.reset!` clears it (used before every spec). Location can be set globally or per-call via the `location:` keyword. It's injected into the system prompt to reduce false positives.

### Rails Integration

`lib/feather_ai/rails/` contains a Railtie and `acts_as_sighting` mixin. When included in an ActiveRecord model, it expects `photo` (ActiveStorage) and `location` (string) attributes, and adds:

- `identify!` — downloads the photo, runs identification, persists species fields, returns the `Result`.
- `correct!(attrs)` / `corrected?` / `correction_delta` — human corrections of AI identifications, stored in `corrected_*` columns with a `corrected_at` timestamp. `correction_delta` always diffs against the original AI values.

Generators: `rails generate feather_ai:install [model_name]` scaffolds the identification-columns migration; `rails generate feather_ai:add_corrections [model_name]` adds the correction columns. Templates live in `lib/generators/feather_ai/templates/`.

## Code Style

- Double quotes for all strings (configured in `.rubocop.yml`)
- `frozen_string_literal: true` in every Ruby file
- Target Ruby version: >= 3.2 (gemspec requires it; CI tests 3.2, 3.3, 3.4)
- RSpec with `expect` syntax only (monkey patching disabled)

## Testing

- Specs stub RubyLLM directly with `instance_double`s (e.g. `allow(RubyLLM).to receive(:chat)`) — no API keys needed. VCR + WebMock are configured in `spec_helper.rb` but mainly serve to block real HTTP; there are no recorded cassettes.
- `spec/support/helpers.rb` provides `build_result(overrides)` for constructing `FeatherAi::Result` test objects.
- `FeatherAi.reset!` runs before every example, so config is always at defaults unless the spec configures it.
- SimpleCov for coverage reporting
- Dev test dependencies go in the `Gemfile`, not the gemspec

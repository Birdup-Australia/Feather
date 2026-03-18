# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Feather is a Ruby gem for identifying birds from photos and audio using RubyLLM. It adds multi-modal identification, location-aware results, multi-model consensus, and a Rails integration on top of RubyLLM.

## Commands

```bash
# Install dependencies
bin/setup

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/feather/identifier_spec.rb

# Run a single example by line number
bundle exec rspec spec/feather/identifier_spec.rb:15

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

The gem's only runtime dependency is `ruby_llm`. All classes live under the `Feather` module in `lib/feather/`.

### Data Flow

`Feather.identify(image, audio, location:, consensus:)` is the top-level entry point defined in `lib/feather.rb`. It delegates to:

1. **Identifier** (`lib/feather/identifier.rb`) — Core identification logic. Uses RubyLLM's vision for images and `RubyLLM.transcribe` for audio. When both inputs are provided, they're combined into a single multi-modal prompt. Uses `RubyLLM::Schema` for structured output so results are always clean `Result` objects, not raw LLM prose.

2. **Consensus** (`lib/feather/consensus.rb`) — When `consensus: true`, runs identification through two configurable models independently. If they agree on species, returns `confident: true`. If they disagree, returns both as `candidates` with uncertain confidence.

3. **Result** (`lib/feather/result.rb`) — Immutable value object wrapping all identification output. Exposes `common_name`, `species`, `family`, `confidence` (`:high`/`:medium`/`:low`), `confident?`, `region_native?`, `candidates`, `photography_tips`, and `to_h`. Photography tips are lazy-loaded via a second cheap LLM call only when accessed.

4. **PhotographyTips** (`lib/feather/photography_tips.rb`) — Separate LLM call (small model) returning structured shooting advice for the identified species. Only invoked when `result.photography_tips` is called.

### Configuration

```ruby
Feather.configure do |c|
  c.provider  = :anthropic
  c.location  = "Perth, Western Australia"  # biases results to local species
  c.model     = "claude-sonnet-4"
end
```

Location can be set globally or per-call via `location:` keyword. It's injected into the system prompt to reduce false positives.

### Rails Integration

`lib/feather/rails/` contains a Railtie and `acts_as_sighting` mixin. When included in an ActiveRecord model, it expects `photo` (ActiveStorage) and `location` (string) attributes, and adds an `identify!` method that populates species fields on the record. A generator (`bin/rails generate feather:install`) scaffolds the migration.

## Code Style

- Double quotes for all strings (configured in `.rubocop.yml`)
- `frozen_string_literal: true` in every Ruby file
- Target Ruby version: >= 3.2 (gemspec requires it; CI tests 3.2, 3.3, 3.4)
- RSpec with `expect` syntax only (monkey patching disabled)

## Testing

- Tests use VCR + WebMock to record/replay real LLM responses — no API keys needed in CI
- Sample bird images (WA birds) live in `spec/support/fixtures/`
- SimpleCov for coverage reporting
- Dev test dependencies go in the `Gemfile`, not the gemspec

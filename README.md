# FeatherAi

[![Gem Version](https://badge.fury.io/rb/feather-ai.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/feather-ai)

A Ruby gem for identifying birds from photos and audio using [RubyLLM](https://github.com/coelacanth/ruby_llm). FeatherAi adds multi-modal identification, location-aware results, multi-model consensus, and a Rails integration on top of RubyLLM.

## Installation

Add to your Gemfile:

```ruby
gem "feather-ai"
```

Or install directly:

```bash
gem install feather-ai
```

## Configuration

```ruby
FeatherAi.configure do |c|
  c.provider         = :anthropic           # Default: :anthropic
  c.model            = "claude-sonnet-4"    # Default: "claude-sonnet-4"
  c.location         = "Perth, WA"          # Optional: biases results to local species
  c.consensus_models = ["claude-sonnet-4", "claude-haiku-4"]  # Models used in consensus mode
  c.tips_model       = "claude-haiku-4"     # Model for photography tips (default)
  c.media_resolution = :high                # Image resolution sent to provider (default)
end
```

RubyLLM must be configured with your provider credentials before using FeatherAi. See the [RubyLLM docs](https://github.com/coelacanth/ruby_llm) for setup.

## Usage

### Basic Identification

Identify a bird from an image:

```ruby
result = FeatherAi.identify("path/to/bird.jpg")

result.common_name   # => "Western Magpie"
result.species       # => "Gymnorhina tibicen"
result.family        # => "Artamidae"
result.confidence    # => :high
result.confident?    # => true
result.region_native? # => true
```

Identify from audio:

```ruby
result = FeatherAi.identify(nil, "path/to/bird_call.mp3")
```

Identify from multiple images at once:

```ruby
result = FeatherAi.identify(["front.jpg", "side.jpg"])
```

Identify from both image and audio:

```ruby
result = FeatherAi.identify("path/to/bird.jpg", "path/to/bird_call.mp3")
```

### Location-Aware Results

Pass a location to bias the model toward species native to that region:

```ruby
result = FeatherAi.identify("path/to/bird.jpg", location: "Perth, Western Australia")

result.region_native? # => true/false based on species range
```

A default location can also be set globally in configuration.

### Consensus Mode

Run identification through two models independently. When both agree on species, you get high confidence. When they disagree, you get the candidates:

```ruby
result = FeatherAi.identify("path/to/bird.jpg", consensus: true)

if result.confident?
  puts "Both models agree: #{result.species}"
else
  puts "Models disagree:"
  result.candidates.each { |c| puts "  #{c.common_name} (#{c.species})" }
end
```

Consensus models are configurable:

```ruby
FeatherAi.configure do |c|
  c.consensus_models = ["claude-sonnet-4", "claude-haiku-4"]
end
```

### Photography Tips

Results expose lazy-loaded photography tips for the identified species. The tips are only fetched (via a fast, cheap model) when you access them:

```ruby
tips = result.photography_tips

tips[:time_of_day]  # => "Early morning or late afternoon for soft light"
tips[:approach]     # => "Move slowly and quietly, approach from below sight line"
tips[:settings]     # => "1/500s or faster, f/2.8-f/4, ISO 400-1600"
tips[:habitat]      # => "Open woodlands, grasslands, and suburban parks"
```

### Result Object

All identification calls return a `FeatherAi::Result`:

| Method | Type | Description |
|---|---|---|
| `common_name` | String | Common name (e.g. "Western Magpie") |
| `species` | String | Scientific name (e.g. "Gymnorhina tibicen") |
| `family` | String | Bird family (e.g. "Artamidae") |
| `confidence` | Symbol | `:high`, `:medium`, or `:low` |
| `confident?` | Boolean | `true` when confidence is `:high` |
| `region_native?` | Boolean | Whether species is native to the given region |
| `candidates` | Array | Alternative results when consensus disagrees |
| `photography_tips` | Hash | Lazy-loaded shooting advice |
| `to_h` | Hash | All fields as a plain hash |

Every result also carries observability data from the LLM call:

| Method | Type | Description |
|---|---|---|
| `reasoning` | String | Step-by-step visual analysis the model performed |
| `model_id` | String | Model that produced the identification |
| `input_tokens` | Integer | Tokens sent to the model |
| `output_tokens` | Integer | Tokens received from the model |
| `cost` | Float | Estimated USD cost (based on built-in rate tables, or `nil`) |
| `duration_ms` | Integer | Wall-clock time of the LLM call in milliseconds |
| `source` | Symbol | `:vision`, `:audio`, or `:multimodal` |
| `consensus_models` | Array | Models used when consensus mode was enabled |

## Rails Integration

### Setup

Run the install generator to scaffold the migration:

```bash
rails generate feather_ai:install
# or with a custom model name:
rails generate feather_ai:install observation
```

Run the migration:

```bash
rails db:migrate
```

### Model

Add `acts_as_sighting` to your ActiveRecord model. The model must have a `photo` attribute (ActiveStorage) and a `location` string column:

```ruby
class Sighting < ApplicationRecord
  has_one_attached :photo
  acts_as_sighting
end
```

The generator adds these columns to the model's table: `common_name`, `species`, `family`, `confidence`, `region_native`.

### Identifying Records

Call `identify!` on any instance to run identification and persist the results:

```ruby
sighting = Sighting.create!(photo: params[:photo], location: "Perth, WA")
result = sighting.identify!

sighting.common_name  # => "Western Magpie"
sighting.species      # => "Gymnorhina tibicen"
sighting.confident?   # => true (delegated through result)
```

`identify!` downloads the attached photo, calls `FeatherAi.identify`, updates the record's identification columns, and returns the `FeatherAi::Result`.

### Corrections

Users or moderators can correct AI identifications. First, run the corrections generator to add the necessary columns:

```bash
rails generate feather_ai:add_corrections
# or with a custom model name:
rails generate feather_ai:add_corrections observation
```

Then apply corrections to a record:

```ruby
sighting.correct!(common_name: "Australian Magpie", species: "Gymnorhina tibicen dorsalis")

sighting.corrected?      # => true
sighting.corrected_at    # => 2026-03-25 12:00:00 UTC

sighting.correction_delta
# => { common_name: { from: "Western Magpie", to: "Australian Magpie" },
#      species:     { from: "Gymnorhina tibicen", to: "Gymnorhina tibicen dorsalis" } }
```

Correctable fields: `common_name`, `species`, `family`, `confidence`, `region_native`.

## Instrumentation

When `ActiveSupport::Notifications` is available (e.g. in Rails), every identification emits an `identify.feather_ai` event. Without ActiveSupport the instrumentation is a no-op.

```ruby
ActiveSupport::Notifications.subscribe("identify.feather_ai") do |_name, _start, _finish, _id, payload|
  Rails.logger.info "Identified #{payload[:result].common_name} " \
                     "with model=#{payload[:model]} in #{payload[:result].duration_ms}ms"
end
```

Payload keys: `model`, `location`, `has_image`, `image_count`, `has_audio`, and `result` (the `FeatherAi::Result`).

## Error Handling

FeatherAi raises specific error classes, all inheriting from `FeatherAi::Error`:

- `FeatherAi::ConfigurationError` — invalid or missing configuration (e.g. no image or audio provided)
- `FeatherAi::IdentificationError` — failure during the LLM identification call

```ruby
begin
  FeatherAi.identify("path/to/bird.jpg")
rescue FeatherAi::ConfigurationError => e
  # handle bad config
rescue FeatherAi::IdentificationError => e
  # handle LLM failure
end
```

## Development

```bash
bin/setup           # Install dependencies
bundle exec rspec   # Run tests
bundle exec rubocop # Lint
bundle exec rake    # Tests + lint (same as CI)
bin/console         # Interactive console with gem loaded
```

Tests use VCR + WebMock to record and replay LLM responses — no API keys are required to run the test suite.

Use `FeatherAi.reset!` to clear configuration between test examples:

```ruby
after { FeatherAi.reset! }
```

## Thread Safety

`FeatherAi.configuration` is a process-level singleton initialised lazily with `||=`. Under MRI Ruby, the Global VM Lock (GVL) makes this safe in practice. If you use JRuby or Ractors, initialise configuration eagerly at boot time before spawning threads:

```ruby
# In an initialiser or boot file — before any threads are created
FeatherAi.configure do |c|
  c.provider = :anthropic
  c.model    = "claude-sonnet-4"
end
```

`FeatherAi.identify` is stateless per-call — each invocation constructs its own `Identifier` or `Consensus` instance and `RubyLLM::Chat` session. Concurrent calls are safe.

`FeatherAi::Consensus` parallelises model calls using Ruby threads (`Thread.new`), so two LLM requests run concurrently and the total wall-clock time is roughly that of the slower model, not the sum of both.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Birdup-Australia/Feather.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

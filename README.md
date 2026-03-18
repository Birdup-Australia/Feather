# Feather

A Ruby gem for identifying birds from photos and audio using [RubyLLM](https://github.com/coelacanth/ruby_llm). Feather adds multi-modal identification, location-aware results, multi-model consensus, and a Rails integration on top of RubyLLM.

## Installation

Add to your Gemfile:

```ruby
gem "feather"
```

Or install directly:

```bash
gem install feather
```

## Configuration

```ruby
Feather.configure do |c|
  c.provider  = :anthropic           # Default: :anthropic
  c.model     = "claude-sonnet-4"    # Default: "claude-sonnet-4"
  c.location  = "Perth, WA"          # Optional: biases results to local species
  c.consensus_models = ["claude-sonnet-4", "claude-haiku-4"]  # Models used in consensus mode
end
```

RubyLLM must be configured with your provider credentials before using Feather. See the [RubyLLM docs](https://github.com/coelacanth/ruby_llm) for setup.

## Usage

### Basic Identification

Identify a bird from an image:

```ruby
result = Feather.identify("path/to/bird.jpg")

result.common_name   # => "Western Magpie"
result.species       # => "Gymnorhina tibicen"
result.family        # => "Artamidae"
result.confidence    # => :high
result.confident?    # => true
result.region_native? # => true
```

Identify from audio:

```ruby
result = Feather.identify(nil, "path/to/bird_call.mp3")
```

Identify from both image and audio:

```ruby
result = Feather.identify("path/to/bird.jpg", "path/to/bird_call.mp3")
```

### Location-Aware Results

Pass a location to bias the model toward species native to that region:

```ruby
result = Feather.identify("path/to/bird.jpg", location: "Perth, Western Australia")

result.region_native? # => true/false based on species range
```

A default location can also be set globally in configuration.

### Consensus Mode

Run identification through two models independently. When both agree on species, you get high confidence. When they disagree, you get the candidates:

```ruby
result = Feather.identify("path/to/bird.jpg", consensus: true)

if result.confident?
  puts "Both models agree: #{result.species}"
else
  puts "Models disagree:"
  result.candidates.each { |c| puts "  #{c.common_name} (#{c.species})" }
end
```

Consensus models are configurable:

```ruby
Feather.configure do |c|
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

All identification calls return a `Feather::Result`:

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

## Rails Integration

### Setup

Run the install generator to scaffold the migration:

```bash
rails generate feather:install
# or with a custom model name:
rails generate feather:install observation
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

`identify!` downloads the attached photo, calls `Feather.identify`, updates the record's identification columns, and returns the `Feather::Result`.

## Development

```bash
bin/setup           # Install dependencies
bundle exec rspec   # Run tests
bundle exec rubocop # Lint
bundle exec rake    # Tests + lint (same as CI)
bin/console         # Interactive console with gem loaded
```

Tests use VCR + WebMock to record and replay LLM responses — no API keys are required to run the test suite.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/GoodPie/feather.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

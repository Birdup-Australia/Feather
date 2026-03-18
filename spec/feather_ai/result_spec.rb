# frozen_string_literal: true

RSpec.describe FeatherAi::Result do
  subject(:result) { described_class.new(attrs) }

  let(:attrs) do
    {
      common_name: "Splendid Fairywren",
      species: "Malurus splendens",
      family: "Maluridae",
      confidence: :high,
      region_native: true
    }
  end

  describe "#confident?" do
    it "returns true when confidence is :high" do
      expect(result.confident?).to be(true)
    end

    it "returns false when confidence is :medium" do
      expect(described_class.new(attrs.merge(confidence: :medium)).confident?).to be(false)
    end

    it "returns false when confidence is :low" do
      expect(described_class.new(attrs.merge(confidence: :low)).confident?).to be(false)
    end
  end

  describe "#region_native?" do
    it "returns true when region_native is true" do
      expect(result.region_native?).to be(true)
    end

    it "returns false when region_native is false" do
      expect(described_class.new(attrs.merge(region_native: false)).region_native?).to be(false)
    end
  end

  describe "#confidence" do
    it "coerces string to symbol" do
      result = described_class.new(attrs.merge(confidence: "high"))
      expect(result.confidence).to eq(:high)
    end
  end

  describe "#photography_tips" do
    it "lazy-loads tips via the loader proc" do
      tips_data = { time_of_day: "dawn", approach: "slow", settings: "f/5.6", habitat: "reeds" }
      loader = -> { tips_data }

      result = described_class.new(attrs.merge(photography_tips_loader: loader))
      expect(result.photography_tips).to eq(tips_data)
    end

    it "returns nil when no loader or data provided" do
      expect(result.photography_tips).to be_nil
    end

    it "caches the tips after first call" do # rubocop:disable RSpec/ExampleLength
      call_count = 0
      loader = lambda {
        call_count += 1
        { time_of_day: "dawn" }
      }
      result = described_class.new(attrs.merge(photography_tips_loader: loader))
      result.photography_tips
      result.photography_tips
      expect(call_count).to eq(1)
    end

    it "does not re-invoke the loader when it returns nil" do # rubocop:disable RSpec/ExampleLength
      call_count = 0
      loader = lambda {
        call_count += 1
        nil
      }
      result = described_class.new(attrs.merge(photography_tips_loader: loader))
      result.photography_tips
      result.photography_tips
      expect(call_count).to eq(1)
    end

    it "returns pre-populated tips on the first call" do
      tips_data = { time_of_day: "dawn", approach: "slow", settings: "f/5.6", habitat: "reeds" }
      result = described_class.new(attrs.merge(photography_tips: tips_data))
      expect(result.photography_tips).to eq(tips_data)
    end

    it "does not overwrite pre-populated tips on subsequent calls" do
      tips_data = { time_of_day: "dawn", approach: "slow", settings: "f/5.6", habitat: "reeds" }
      result = described_class.new(attrs.merge(photography_tips: tips_data))
      result.photography_tips
      expect(result.photography_tips).to eq(tips_data)
    end
  end

  describe "observability fields" do
    subject(:rich_result) { described_class.new(observability_attrs) }

    let(:observability_attrs) do
      attrs.merge(
        model_id: "claude-sonnet-4-6",
        input_tokens: 512,
        output_tokens: 128,
        cost: 0.003456,
        duration_ms: 820,
        source: :vision,
        consensus_models: nil
      )
    end

    it "exposes model_id" do
      expect(rich_result.model_id).to eq("claude-sonnet-4-6")
    end

    it "exposes input_tokens" do
      expect(rich_result.input_tokens).to eq(512)
    end

    it "exposes output_tokens" do
      expect(rich_result.output_tokens).to eq(128)
    end

    it "exposes cost" do
      expect(rich_result.cost).to be_within(0.000001).of(0.003456)
    end

    it "exposes duration_ms" do
      expect(rich_result.duration_ms).to eq(820)
    end

    it "exposes source as a symbol" do
      expect(rich_result.source).to eq(:vision)
    end

    it "returns nil for consensus_models on a single-model result" do
      expect(rich_result.consensus_models).to be_nil
    end

    it "exposes consensus_models when set" do
      models = ["claude-sonnet-4-6", "claude-haiku-4"]
      result = described_class.new(observability_attrs.merge(consensus_models: models))
      expect(result.consensus_models).to eq(models)
    end

    it "defaults all observability fields to nil when not provided" do # rubocop:disable RSpec/ExampleLength
      aggregate_failures do
        expect(result.model_id).to be_nil
        expect(result.input_tokens).to be_nil
        expect(result.output_tokens).to be_nil
        expect(result.cost).to be_nil
        expect(result.duration_ms).to be_nil
        expect(result.source).to be_nil
        expect(result.consensus_models).to be_nil
      end
    end
  end

  describe "#to_h" do
    it "returns a plain hash" do
      expect(result.to_h).to be_a(Hash)
    end

    it "includes all key fields" do # rubocop:disable RSpec/ExampleLength
      hash = result.to_h
      aggregate_failures do
        expect(hash[:common_name]).to eq("Splendid Fairywren")
        expect(hash[:species]).to eq("Malurus splendens")
        expect(hash[:family]).to eq("Maluridae")
        expect(hash[:confidence]).to eq(:high)
        expect(hash[:confident]).to be(true)
        expect(hash[:region_native]).to be(true)
      end
    end

    it "includes observability fields" do # rubocop:disable RSpec/ExampleLength
      result = described_class.new(
        attrs.merge(
          model_id: "claude-sonnet-4-6",
          input_tokens: 512,
          output_tokens: 128,
          cost: 0.003456,
          duration_ms: 820,
          source: :vision,
          consensus_models: nil
        )
      )
      hash = result.to_h
      aggregate_failures do
        expect(hash[:model_id]).to eq("claude-sonnet-4-6")
        expect(hash[:input_tokens]).to eq(512)
        expect(hash[:output_tokens]).to eq(128)
        expect(hash[:duration_ms]).to eq(820)
        expect(hash[:source]).to eq(:vision)
        expect(hash[:consensus_models]).to be_nil
        expect(hash[:cost]).to be_within(0.000001).of(0.003456)
      end
    end

    it "triggers the photography_tips loader so tips appear in the hash" do
      tips_data = { time_of_day: "dawn", approach: "slow", settings: "f/5.6", habitat: "reeds" }
      result = described_class.new(attrs.merge(photography_tips_loader: -> { tips_data }))
      expect(result.to_h[:photography_tips]).to eq(tips_data)
    end
  end
end

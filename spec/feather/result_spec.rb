# frozen_string_literal: true

RSpec.describe Feather::Result do
  let(:attrs) do
    {
      common_name: "Splendid Fairywren",
      species: "Malurus splendens",
      family: "Maluridae",
      confidence: :high,
      region_native: true,
    }
  end

  subject(:result) { described_class.new(attrs) }

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

    it "caches the tips after first call" do
      call_count = 0
      loader = -> { call_count += 1; { time_of_day: "dawn" } }

      result = described_class.new(attrs.merge(photography_tips_loader: loader))
      result.photography_tips
      result.photography_tips

      expect(call_count).to eq(1)
    end

    it "does not re-invoke the loader when it returns nil" do
      call_count = 0
      loader = -> { call_count += 1; nil }

      result = described_class.new(attrs.merge(photography_tips_loader: loader))
      result.photography_tips
      result.photography_tips

      expect(call_count).to eq(1)
    end
  end

  describe "#to_h" do
    it "returns a plain hash" do
      expect(result.to_h).to be_a(Hash)
    end

    it "includes all key fields" do
      hash = result.to_h
      expect(hash).to include(
        common_name: "Splendid Fairywren",
        species: "Malurus splendens",
        family: "Maluridae",
        confidence: :high,
        confident: true,
        region_native: true,
      )
    end

    it "triggers the photography_tips loader so tips appear in the hash" do
      tips_data = { time_of_day: "dawn", approach: "slow", settings: "f/5.6", habitat: "reeds" }
      result = described_class.new(attrs.merge(photography_tips_loader: -> { tips_data }))
      expect(result.to_h[:photography_tips]).to eq(tips_data)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Feather::Identifier do
  let(:identifier) { described_class.new }

  let(:mock_response) do
    {
      "common_name" => "Splendid Fairywren",
      "species" => "Malurus splendens",
      "family" => "Maluridae",
      "confidence" => "high",
      "region_native" => true
    }
  end

  let(:mock_chat) { instance_double(RubyLLM::Chat) }

  before do
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
    allow(mock_chat).to receive(:with_schema).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(double(content: mock_response))
  end

  describe "#identify" do
    it "returns a Result" do
      result = identifier.identify("bird.jpg")
      expect(result).to be_a(Feather::Result)
    end

    it "populates result fields from the LLM response" do
      result = identifier.identify("bird.jpg")
      expect(result.common_name).to eq("Splendid Fairywren")
      expect(result.species).to eq("Malurus splendens")
      expect(result.family).to eq("Maluridae")
      expect(result.confidence).to eq(:high)
      expect(result.region_native?).to be(true)
    end

    it "includes the configured location in the system prompt when set" do
      config = Feather::Configuration.new
      config.location = "Perth, Western Australia"
      identifier = described_class.new(config: config)

      identifier.identify("bird.jpg")

      expect(mock_chat).to have_received(:with_instructions).with(
        include("Perth, Western Australia")
      )
    end

    it "overrides the configured location with a per-call location" do
      config = Feather::Configuration.new
      config.location = "Sydney"
      identifier = described_class.new(config: config)

      identifier.identify("bird.jpg", location: "Brisbane")

      expect(mock_chat).to have_received(:with_instructions).with(
        include("Brisbane")
      )
    end

    it "lazy-loads photography tips" do
      result = identifier.identify("bird.jpg")
      expect(RubyLLM).not_to have_received(:chat).with(hash_including(model: "claude-haiku-4"))
      expect(result).to respond_to(:photography_tips)
    end
  end
end

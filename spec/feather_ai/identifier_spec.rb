# frozen_string_literal: true

RSpec.describe FeatherAi::Identifier do
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
    allow(mock_chat).to receive_messages(with_instructions: mock_chat, with_schema: mock_chat, ask: double(
      content: mock_response,
      model_id: "claude-sonnet-4-6",
      input_tokens: 512,
      output_tokens: 64
    ))
  end

  describe "#identify" do
    it "raises feather::ConfigurationError when both image and audio are nil" do
      expect { identifier.identify }.to raise_error(
        FeatherAi::ConfigurationError,
        /At least one of image or audio must be provided/
      )
    end

    it "raises feather::ConfigurationError when both are explicitly nil" do
      expect { identifier.identify(nil, nil) }.to raise_error(FeatherAi::ConfigurationError)
    end

    it "returns a Result" do
      result = identifier.identify("bird.jpg")
      expect(result).to be_a(FeatherAi::Result)
    end

    it "populates result fields from the LLM response" do # rubocop:disable RSpec/ExampleLength
      result = identifier.identify("bird.jpg")
      aggregate_failures do
        expect(result.common_name).to eq("Splendid Fairywren")
        expect(result.species).to eq("Malurus splendens")
        expect(result.family).to eq("Maluridae")
        expect(result.confidence).to eq(:high)
        expect(result.region_native?).to be(true)
      end
    end

    it "includes the configured location in the system prompt when set" do
      config = FeatherAi::Configuration.new
      config.location = "Perth, Western Australia"
      identifier = described_class.new(config: config)
      identifier.identify("bird.jpg")
      expect(mock_chat).to have_received(:with_instructions).with(include("Perth, Western Australia"))
    end

    it "overrides the configured location with a per-call location" do
      config = FeatherAi::Configuration.new
      config.location = "Sydney"
      identifier = described_class.new(config: config)
      identifier.identify("bird.jpg", location: "Brisbane")
      expect(mock_chat).to have_received(:with_instructions).with(include("Brisbane"))
    end

    it "lazy-loads photography tips" do
      result = identifier.identify("bird.jpg")
      aggregate_failures do
        expect(RubyLLM).not_to have_received(:chat).with(hash_including(model: "claude-haiku-4"))
        expect(result).to respond_to(:photography_tips)
      end
    end

    it "sets model_id from the LLM response" do
      result = identifier.identify("bird.jpg")
      expect(result.model_id).to eq("claude-sonnet-4-6")
    end

    it "sets token counts from the LLM response" do
      result = identifier.identify("bird.jpg")
      aggregate_failures do
        expect(result.input_tokens).to eq(512)
        expect(result.output_tokens).to eq(64)
      end
    end

    it "computes a non-nil cost when token counts are present" do
      result = identifier.identify("bird.jpg")
      aggregate_failures do
        expect(result.cost).to be_a(Float)
        expect(result.cost).to be_positive
      end
    end

    it "returns nil cost when token counts are absent" do
      allow(mock_chat).to receive(:ask).and_return(
        double(content: mock_response, model_id: "claude-sonnet-4-6", input_tokens: nil, output_tokens: nil)
      )
      result = identifier.identify("bird.jpg")
      expect(result.cost).to be_nil
    end

    it "returns nil cost for a non-anthropic provider" do
      config = FeatherAi::Configuration.new
      config.provider = :openai
      result = described_class.new(config: config).identify("bird.jpg")
      expect(result.cost).to be_nil
    end

    it "records duration_ms as a non-negative integer" do
      result = identifier.identify("bird.jpg")
      aggregate_failures do
        expect(result.duration_ms).to be_a(Integer)
        expect(result.duration_ms).to be >= 0
      end
    end

    it "sets source to :vision for image-only input" do
      result = identifier.identify("bird.jpg")
      expect(result.source).to eq(:vision)
    end

    it "sets source to :audio for audio-only input" do
      allow(RubyLLM).to receive(:transcribe).and_return("chirp chirp")
      result = identifier.identify(nil, "bird.mp3")
      expect(result.source).to eq(:audio)
    end

    it "sets source to :multimodal when both image and audio are provided" do
      allow(RubyLLM).to receive(:transcribe).and_return("chirp chirp")
      result = identifier.identify("bird.jpg", "bird.mp3")
      expect(result.source).to eq(:multimodal)
    end

    it "sets consensus_models to nil for single-model calls" do
      result = identifier.identify("bird.jpg")
      expect(result.consensus_models).to be_nil
    end

    context "with multiple images" do
      it "accepts an array of image paths" do
        result = identifier.identify(%w[front.jpg side.jpg back.jpg])
        expect(result).to be_a(FeatherAi::Result)
      end

      it "sends all images as separate image parts in the message" do # rubocop:disable RSpec/MultipleExpectations
        identifier.identify(%w[front.jpg side.jpg])
        expect(mock_chat).to have_received(:ask) do |message|
          image_parts = message.select { |p| p[:type] == :image }
          expect(image_parts.map { |p| p[:content] }).to eq(%w[front.jpg side.jpg])
        end
      end

      it "uses a multi-image prompt when multiple images are provided" do # rubocop:disable RSpec/MultipleExpectations
        identifier.identify(%w[front.jpg side.jpg])
        expect(mock_chat).to have_received(:ask) do |message|
          text_parts = message.select { |p| p[:type] == :text }
          expect(text_parts.last[:content]).to include("all images together")
        end
      end

      it "sets source to :vision for multiple images without audio" do
        result = identifier.identify(%w[front.jpg side.jpg])
        expect(result.source).to eq(:vision)
      end

      it "sets source to :multimodal for multiple images with audio" do
        allow(RubyLLM).to receive(:transcribe).and_return("chirp chirp")
        result = identifier.identify(%w[front.jpg side.jpg], "bird.mp3")
        expect(result.source).to eq(:multimodal)
      end

      it "treats a single string the same as a single-element array" do # rubocop:disable RSpec/MultipleExpectations
        identifier.identify("bird.jpg")
        expect(mock_chat).to have_received(:ask) do |message|
          image_parts = message.select { |p| p[:type] == :image }
          expect(image_parts.size).to eq(1)
        end
      end

      it "raises ConfigurationError for an empty array with no audio" do
        expect { identifier.identify([]) }.to raise_error(FeatherAi::ConfigurationError)
      end

      it "raises ArgumentError for non-String/Array input" do
        expect { identifier.identify({ path: "bird.jpg" }) }.to raise_error(ArgumentError, /got Hash/)
      end

      it "uses a multimodal prompt when multiple images and audio are provided" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        allow(RubyLLM).to receive(:transcribe).and_return("chirp chirp")
        identifier.identify(%w[front.jpg side.jpg], "bird.mp3")
        expect(mock_chat).to have_received(:ask) do |message|
          text_parts = message.select { |p| p[:type] == :text }
          expect(text_parts.last[:content]).to include("images and heard in the audio")
        end
      end
    end
  end
end

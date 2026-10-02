# frozen_string_literal: true

RSpec.describe FeatherAi::Identifier do
  let(:identifier) { described_class.new }

  let(:mock_response) do
    {
      "reasoning" => "Small passerine with vivid cobalt-blue plumage on head, back, and tail. " \
                     "Black eye-band and breast-band. Not a fairy-wren due to deeper blue.",
      "common_name" => "Splendid Fairywren",
      "species" => "Malurus splendens",
      "family" => "Maluridae",
      "confidence" => "high",
      "region_native" => true,
      "candidates" => [
        { "common_name" => "Splendid Fairywren", "species" => "Malurus splendens", "score" => 0.9 },
        { "common_name" => "Superb Fairywren", "species" => "Malurus cyaneus", "score" => 0.1 }
      ]
    }
  end

  let(:mock_chat) { instance_double(RubyLLM::Chat, provider: double(slug: "anthropic")) }
  let(:mock_response_message) do
    double(parsed: mock_response, model: "claude-sonnet-4-6", tokens: double(input: 512, output: 64),
           cost: double(total: 0.0025))
  end
  let(:lookup_tool) { double("SpeciesLookupTool") } # rubocop:disable RSpec/VerifiedDoubles

  before do
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive_messages(with_instructions: mock_chat, with_schema: mock_chat,
                                         with_tools: mock_chat, with_provider_options: mock_chat,
                                         ask: mock_response_message)
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
        expect(RubyLLM).not_to have_received(:chat).with(hash_including(model: "claude-haiku-4-5"))
        expect(result).to respond_to(:photography_tips)
      end
    end

    it "parses ranked candidates into symbol-keyed hashes" do
      top = { common_name: "Splendid Fairywren", species: "Malurus splendens", score: 0.9 }
      runner_up = { common_name: "Superb Fairywren", species: "Malurus cyaneus", score: 0.1 }
      expect(identifier.identify("bird.jpg").candidates).to eq([top, runner_up])
    end

    it "returns empty candidates when the response omits them" do
      allow(mock_chat).to receive(:ask)
        .and_return(double(parsed: mock_response.except("candidates"), model: "m",
                           tokens: double(input: 1, output: 1), cost: double(total: nil)))
      expect(identifier.identify("bird.jpg").candidates).to eq([])
    end

    context "with tools" do
      it "does not register tools when none are configured" do
        identifier.identify("bird.jpg")
        expect(mock_chat).not_to have_received(:with_tools)
      end

      it "passes per-call tools to the chat" do
        identifier.identify("bird.jpg", tools: [lookup_tool])
        expect(mock_chat).to have_received(:with_tools).with(lookup_tool)
      end

      it "falls back to configured tools" do
        config = FeatherAi::Configuration.new
        config.tools = [lookup_tool]
        described_class.new(config: config).identify("bird.jpg")
        expect(mock_chat).to have_received(:with_tools).with(lookup_tool)
      end

      it "treats nil configured tools as no tools" do
        config = FeatherAi::Configuration.new
        config.tools = nil
        described_class.new(config: config).identify("bird.jpg")
        expect(mock_chat).not_to have_received(:with_tools)
      end

      it "wraps a bare tool passed without an array" do
        identifier.identify("bird.jpg", tools: lookup_tool)
        expect(mock_chat).to have_received(:with_tools).with(lookup_tool)
      end

      it "mentions the lookup tools in the system prompt" do
        identifier.identify("bird.jpg", tools: [lookup_tool])
        expect(mock_chat).to have_received(:with_instructions).with(include("lookup tools"))
      end

      it "does not mention lookup tools in the system prompt without tools" do
        identifier.identify("bird.jpg")
        expect(mock_chat).to have_received(:with_instructions).with(satisfy { |p| !p.include?("lookup tools") })
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

    it "passes through the cost RubyLLM computes" do
      result = identifier.identify("bird.jpg")
      expect(result.cost).to eq(0.0025)
    end

    it "returns nil cost when RubyLLM has no pricing" do
      unpriced = double(parsed: mock_response, model: "m", tokens: double(input: 1, output: 1),
                        cost: double(total: nil))
      allow(mock_chat).to receive(:ask).and_return(unpriced)
      expect(identifier.identify("bird.jpg").cost).to be_nil
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
      allow(RubyLLM).to receive(:transcribe).and_return(double(text: "chirp chirp"))
      result = identifier.identify(nil, "bird.mp3")
      expect(result.source).to eq(:audio)
    end

    it "puts the transcript text into the prompt" do
      allow(RubyLLM).to receive(:transcribe).and_return(double(text: "chirp chirp"))
      identifier.identify(nil, "bird.mp3")
      expect(mock_chat).to have_received(:ask).with(include("transcript: chirp chirp"), with: nil)
    end

    it "sets source to :multimodal when both image and audio are provided" do
      allow(RubyLLM).to receive(:transcribe).and_return(double(text: "chirp chirp"))
      result = identifier.identify("bird.jpg", "bird.mp3")
      expect(result.source).to eq(:multimodal)
    end

    it "sets consensus_models to nil for single-model calls" do
      result = identifier.identify("bird.jpg")
      expect(result.consensus_models).to be_nil
    end

    it "populates reasoning from the LLM response" do
      result = identifier.identify("bird.jpg")
      expect(result.reasoning).to include("cobalt-blue")
    end

    it "does not send Gemini media_resolution to non-Gemini providers" do
      identifier.identify("bird.jpg")
      expect(mock_chat).not_to have_received(:with_provider_options)
    end

    context "with a Gemini model" do
      before { allow(mock_chat).to receive(:provider).and_return(double(slug: "gemini")) }

      it "passes media_resolution HIGH by default" do
        identifier.identify("bird.jpg")
        expect(mock_chat).to have_received(:with_provider_options).with(
          generationConfig: { mediaResolution: "MEDIA_RESOLUTION_HIGH" }
        )
      end

      it "respects a custom media_resolution config" do # rubocop:disable RSpec/ExampleLength
        config = FeatherAi::Configuration.new
        config.media_resolution = :medium
        described_class.new(config: config).identify("bird.jpg")
        expect(mock_chat).to have_received(:with_provider_options).with(
          generationConfig: { mediaResolution: "MEDIA_RESOLUTION_MEDIUM" }
        )
      end

      it "skips provider options when media_resolution is nil" do
        config = FeatherAi::Configuration.new
        config.media_resolution = nil
        described_class.new(config: config).identify("bird.jpg")
        expect(mock_chat).not_to have_received(:with_provider_options)
      end
    end

    context "with multiple images" do
      it "accepts an array of image paths" do
        result = identifier.identify(%w[front.jpg side.jpg back.jpg])
        expect(result).to be_a(FeatherAi::Result)
      end

      it "sends all images as attachments via with:" do
        identifier.identify(%w[front.jpg side.jpg])
        expect(mock_chat).to have_received(:ask).with(anything, with: %w[front.jpg side.jpg])
      end

      it "uses a multi-image prompt when multiple images are provided" do
        identifier.identify(%w[front.jpg side.jpg])
        expect(mock_chat).to have_received(:ask).with(include("all images together"), with: anything)
      end

      it "sets source to :vision for multiple images without audio" do
        result = identifier.identify(%w[front.jpg side.jpg])
        expect(result.source).to eq(:vision)
      end

      it "sets source to :multimodal for multiple images with audio" do
        allow(RubyLLM).to receive(:transcribe).and_return(double(text: "chirp chirp"))
        result = identifier.identify(%w[front.jpg side.jpg], "bird.mp3")
        expect(result.source).to eq(:multimodal)
      end

      it "treats a single string the same as a single-element array" do
        identifier.identify("bird.jpg")
        expect(mock_chat).to have_received(:ask).with(anything, with: ["bird.jpg"])
      end

      it "raises ConfigurationError for an empty array with no audio" do
        expect { identifier.identify([]) }.to raise_error(FeatherAi::ConfigurationError)
      end

      it "raises ArgumentError for non-String/Array input" do
        expect { identifier.identify({ path: "bird.jpg" }) }.to raise_error(ArgumentError, /got Hash/)
      end

      it "uses a multimodal prompt when multiple images and audio are provided" do
        allow(RubyLLM).to receive(:transcribe).and_return(double(text: "chirp chirp"))
        identifier.identify(%w[front.jpg side.jpg], "bird.mp3")
        expect(mock_chat).to have_received(:ask).with(include("images and heard in the audio"), with: anything)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe FeatherAi::Consensus do
  let(:consensus) { described_class.new }

  let(:fairywren_result) do
    FeatherAi::Result.new(
      common_name: "Splendid Fairywren",
      species: "Malurus splendens",
      family: "Maluridae",
      confidence: :high,
      region_native: true,
      candidates: [{ common_name: "Splendid Fairywren", species: "Malurus splendens", score: 0.9 }]
    )
  end

  let(:magpie_result) do
    FeatherAi::Result.new(
      common_name: "Australian Magpie",
      species: "Gymnorhina tibicen",
      family: "Artamidae",
      confidence: :medium,
      region_native: true
    )
  end

  describe "#identify" do
    context "when models agree on species" do
      before do
        call_count = 0
        allow_any_instance_of(FeatherAi::Identifier).to receive(:identify) do # rubocop:disable RSpec/AnyInstance
          call_count += 1
          fairywren_result
        end
      end

      it "returns a confident Result" do
        result = consensus.identify("bird.jpg")
        expect(result.confidence).to eq(:high)
      end

      it "returns the agreed-upon species" do
        result = consensus.identify("bird.jpg")
        expect(result.species).to eq("Malurus splendens")
      end

      it "carries the primary result's ranked candidates" do
        result = consensus.identify("bird.jpg")
        expect(result.candidates).to eq(fairywren_result.candidates)
      end
    end

    context "when models disagree on species" do
      let(:results) { [fairywren_result, magpie_result] }

      before do
        call_count = 0
        allow_any_instance_of(FeatherAi::Identifier).to receive(:identify) do # rubocop:disable RSpec/AnyInstance
          results[call_count].tap { call_count += 1 }
        end
      end

      it "returns a low-confidence Result" do
        result = consensus.identify("bird.jpg")
        expect(result.confidence).to eq(:low)
      end

      it "includes both candidates" do
        result = consensus.identify("bird.jpg")
        expect(result.candidates.length).to eq(2)
      end

      it "returns candidates as vote-share hashes" do
        result = consensus.identify("bird.jpg")
        expect(result.candidates).to contain_exactly(
          { common_name: "Splendid Fairywren", species: "Malurus splendens", score: 0.5 },
          { common_name: "Australian Magpie", species: "Gymnorhina tibicen", score: 0.5 }
        )
      end

      it "returns nil for species" do
        result = consensus.identify("bird.jpg")
        expect(result.species).to be_nil
      end

      it "returns nil for family when families also differ" do
        result = consensus.identify("bird.jpg")
        expect(result.family).to be_nil
      end
    end

    context "when models disagree on species but agree on family" do
      let(:splendid) do
        FeatherAi::Result.new(
          common_name: "Splendid Fairywren",
          species: "Malurus splendens",
          family: "Maluridae",
          confidence: :high,
          region_native: true
        )
      end

      let(:variegated) do
        FeatherAi::Result.new(
          common_name: "Variegated Fairywren",
          species: "Malurus assimilis",
          family: "Maluridae",
          confidence: :medium,
          region_native: true
        )
      end

      before do
        call_count = 0
        results = [splendid, variegated]
        allow_any_instance_of(FeatherAi::Identifier).to receive(:identify) do # rubocop:disable RSpec/AnyInstance
          results[call_count].tap { call_count += 1 }
        end
      end

      it "sets family to the agreed family" do
        result = consensus.identify("bird.jpg")
        expect(result.family).to eq("Maluridae")
      end

      it "is still low confidence" do
        result = consensus.identify("bird.jpg")
        expect(result.confidence).to eq(:low)
      end
    end

    context "with tools" do
      let(:lookup_tool) { double("SpeciesLookupTool") } # rubocop:disable RSpec/VerifiedDoubles
      let(:captured_tools) { [] }

      before do
        allow_any_instance_of(FeatherAi::Identifier).to receive(:identify) do |_id, *_args, **kwargs| # rubocop:disable RSpec/AnyInstance
          captured_tools << kwargs[:tools]
          fairywren_result
        end
      end

      it "forwards tools to each identifier" do
        consensus.identify("bird.jpg", tools: [lookup_tool])
        expect(captured_tools).to eq([[lookup_tool], [lookup_tool]])
      end
    end

    context "with config isolation" do
      before do
        allow_any_instance_of(FeatherAi::Identifier).to receive(:identify).and_return(fairywren_result) # rubocop:disable RSpec/AnyInstance
      end

      it "does not mutate the global configuration model during consensus" do
        original_model = FeatherAi.configuration.model
        consensus.identify("bird.jpg")
        expect(FeatherAi.configuration.model).to eq(original_model)
      end
    end
  end
end

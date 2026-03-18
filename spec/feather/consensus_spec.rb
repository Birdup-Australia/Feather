# frozen_string_literal: true

RSpec.describe Feather::Consensus do
  let(:consensus) { described_class.new }

  let(:fairywren_result) do
    Feather::Result.new(
      common_name: "Splendid Fairywren",
      species: "Malurus splendens",
      family: "Maluridae",
      confidence: :high,
      region_native: true,
    )
  end

  let(:magpie_result) do
    Feather::Result.new(
      common_name: "Australian Magpie",
      species: "Gymnorhina tibicen",
      family: "Artamidae",
      confidence: :medium,
      region_native: true,
    )
  end

  describe "#identify" do
    context "when models agree on species" do
      before do
        call_count = 0
        allow_any_instance_of(Feather::Identifier).to receive(:identify) do
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
    end

    context "when models disagree on species" do
      let(:results) { [fairywren_result, magpie_result] }

      before do
        call_count = 0
        allow_any_instance_of(Feather::Identifier).to receive(:identify) do
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

      it "returns nil for species" do
        result = consensus.identify("bird.jpg")
        expect(result.species).to be_nil
      end
    end
  end
end

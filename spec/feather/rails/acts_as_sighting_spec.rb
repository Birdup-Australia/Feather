# frozen_string_literal: true

require "feather/rails/acts_as_sighting"

RSpec.describe Feather::Rails::ActsAsSighting do
  # Minimal plain-Ruby double simulating an ActiveRecord model with
  # the identification + correction columns that acts_as_sighting expects.
  let(:sighting_class) do
    Class.new do
      include Feather::Rails::ActsAsSighting::InstanceMethods

      attr_accessor :common_name, :species, :family, :confidence, :region_native,
                    :corrected_common_name, :corrected_species, :corrected_family,
                    :corrected_confidence, :corrected_region_native, :corrected_at

      def update!(attrs)
        attrs.each { |k, v| public_send(:"#{k}=", v) }
        self
      end
    end
  end

  subject(:sighting) { sighting_class.new }

  before do
    sighting.common_name   = "Splendid Fairywren"
    sighting.species       = "Malurus splendens"
    sighting.family        = "Maluridae"
    sighting.confidence    = "high"
    sighting.region_native = true

    # Time.current is an ActiveSupport method unavailable in this test env.
    # Stub it on the Time class so correct! can call it without Rails loaded.
    allow(Time).to receive(:current).and_return(Time.now)
  end

  describe "#correct!" do
    it "persists the corrected value to the prefixed column" do
      sighting.correct!(common_name: "Variegated Fairywren")
      expect(sighting.corrected_common_name).to eq("Variegated Fairywren")
    end

    it "sets corrected_at to a non-nil value" do
      sighting.correct!(common_name: "Variegated Fairywren")
      expect(sighting.corrected_at).not_to be_nil
    end

    it "does not modify the original AI identification column" do
      sighting.correct!(common_name: "Variegated Fairywren")
      expect(sighting.common_name).to eq("Splendid Fairywren")
    end

    it "accepts string keys as well as symbol keys" do
      sighting.correct!("common_name" => "Variegated Fairywren")
      expect(sighting.corrected_common_name).to eq("Variegated Fairywren")
    end

    it "corrects multiple fields in a single call" do
      sighting.correct!(common_name: "Variegated Fairywren", species: "Malurus assimilis")
      expect(sighting.corrected_common_name).to eq("Variegated Fairywren")
      expect(sighting.corrected_species).to eq("Malurus assimilis")
    end

    it "issues a single update! call for atomicity" do
      expect(sighting).to receive(:update!).once.and_call_original
      sighting.correct!(common_name: "Variegated Fairywren", species: "Malurus assimilis")
    end

    it "overwrites a previous correction when called again" do
      sighting.correct!(common_name: "Variegated Fairywren")
      sighting.correct!(common_name: "Purple-crowned Fairywren")
      expect(sighting.corrected_common_name).to eq("Purple-crowned Fairywren")
    end

    it "raises ArgumentError for fields outside the allowed set" do
      expect { sighting.correct!(photo: "photo.jpg") }.to raise_error(
        ArgumentError,
        /Unknown correctable field/
      )
    end

    it "includes the offending field name in the ArgumentError message" do
      expect { sighting.correct!(user_id: 42) }.to raise_error(
        ArgumentError,
        /user_id/
      )
    end

    it "returns without calling update! when attrs is empty" do
      expect(sighting).not_to receive(:update!)
      sighting.correct!({})
    end

    it "does not set corrected_at when attrs is empty" do
      sighting.correct!({})
      expect(sighting.corrected_at).to be_nil
    end
  end

  describe "#corrected?" do
    it "returns false before any correction is applied" do
      expect(sighting.corrected?).to be(false)
    end

    it "returns true after correct! is called" do
      sighting.correct!(common_name: "Variegated Fairywren")
      expect(sighting.corrected?).to be(true)
    end
  end

  describe "#correction_delta" do
    it "returns an empty hash before any correction is applied" do
      expect(sighting.correction_delta).to eq({})
    end

    it "returns a hash with from/to pairs for the corrected field" do
      sighting.correct!(common_name: "Variegated Fairywren")

      expect(sighting.correction_delta).to eq(
        common_name: { from: "Splendid Fairywren", to: "Variegated Fairywren" }
      )
    end

    it "includes all corrected fields when multiple fields are corrected" do
      sighting.correct!(common_name: "Variegated Fairywren", species: "Malurus assimilis")

      expect(sighting.correction_delta).to include(
        common_name: { from: "Splendid Fairywren", to: "Variegated Fairywren" },
        species: { from: "Malurus splendens", to: "Malurus assimilis" }
      )
    end

    it "only includes fields that were explicitly corrected" do
      sighting.correct!(common_name: "Variegated Fairywren")
      expect(sighting.correction_delta.keys).to eq([:common_name])
    end

    it "reflects the latest correction value in :to after re-correction" do
      sighting.correct!(common_name: "Variegated Fairywren")
      sighting.correct!(common_name: "Purple-crowned Fairywren")
      expect(sighting.correction_delta[:common_name][:to]).to eq("Purple-crowned Fairywren")
    end

    it "preserves the original AI value in :from regardless of re-corrections" do
      sighting.correct!(common_name: "Variegated Fairywren")
      sighting.correct!(common_name: "Purple-crowned Fairywren")
      expect(sighting.correction_delta[:common_name][:from]).to eq("Splendid Fairywren")
    end
  end

  describe "CORRECTABLE_FIELDS" do
    it "contains exactly the five identification field names" do
      expect(described_class::CORRECTABLE_FIELDS).to contain_exactly(
        :common_name, :species, :family, :confidence, :region_native
      )
    end

    it "is frozen" do
      expect(described_class::CORRECTABLE_FIELDS).to be_frozen
    end
  end
end

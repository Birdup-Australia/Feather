# frozen_string_literal: true

RSpec.describe Feather do
  it "has a version number" do
    expect(Feather::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "yields the configuration object" do
      described_class.configure do |c|
        c.location = "Perth, Western Australia"
      end

      expect(described_class.configuration.location).to eq("Perth, Western Australia")
    end
  end

  describe ".identify" do
    it "delegates to Identifier by default" do
      identifier = instance_double(Feather::Identifier)
      allow(Feather::Identifier).to receive(:new).and_return(identifier)
      allow(identifier).to receive(:identify).and_return(instance_double(Feather::Result))

      described_class.identify("bird.jpg")

      expect(identifier).to have_received(:identify).with("bird.jpg", nil, location: nil)
    end

    it "delegates to Consensus when consensus: true" do
      consensus = instance_double(Feather::Consensus)
      allow(Feather::Consensus).to receive(:new).and_return(consensus)
      allow(consensus).to receive(:identify).and_return(instance_double(Feather::Result))

      described_class.identify("bird.jpg", consensus: true)

      expect(consensus).to have_received(:identify).with("bird.jpg", nil, location: nil)
    end
  end
end

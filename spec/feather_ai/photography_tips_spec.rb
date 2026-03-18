# frozen_string_literal: true

RSpec.describe FeatherAi::PhotographyTips do
  let(:tips) { described_class.new(species: "Malurus splendens", common_name: "Splendid Fairywren") }

  let(:tips_response) do
    {
      "time_of_day" => "Early morning, just after sunrise",
      "approach" => "Move slowly and stay low, keeping distance of at least 5 metres",
      "settings" => "f/5.6, 1/1000s, ISO 400",
      "habitat" => "Dense low scrub near water"
    }
  end

  let(:mock_chat) { instance_double(RubyLLM::Chat) }

  before do
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive_messages(with_schema: mock_chat, ask: double(content: tips_response))
  end

  describe "#fetch" do
    it "returns a hash with the expected keys" do
      result = tips.fetch
      expect(result.keys).to contain_exactly(:time_of_day, :approach, :settings, :habitat)
    end

    it "includes the LLM-returned values" do
      result = tips.fetch
      aggregate_failures do
        expect(result[:time_of_day]).to eq("Early morning, just after sunrise")
        expect(result[:habitat]).to eq("Dense low scrub near water")
      end
    end
  end
end

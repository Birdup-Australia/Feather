# frozen_string_literal: true

module Feather
  class PhotographyTips
    SCHEMA = RubyLLM::Schema.define do
      property :time_of_day, type: :string, description: "Best time of day to photograph this species"
      property :approach, type: :string, description: "How to approach without disturbing the bird"
      property :settings, type: :string, description: "Recommended camera settings (shutter speed, aperture, ISO)"
      property :habitat, type: :string, description: "Where to find this species for photography"
    end

    def initialize(species:, common_name:)
      @species = species
      @common_name = common_name
    end

    def fetch
      response = RubyLLM.chat(model: "claude-haiku-4").ask(prompt)
      parsed = response.structured(SCHEMA)
      {
        time_of_day: parsed.time_of_day,
        approach: parsed.approach,
        settings: parsed.settings,
        habitat: parsed.habitat,
      }
    end

    private

    def prompt
      "Provide concise bird photography tips for #{@common_name} (#{@species}). " \
        "Include best time of day, how to approach, recommended camera settings, and ideal habitat for photography."
    end
  end
end

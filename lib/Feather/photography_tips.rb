# frozen_string_literal: true

module Feather
  class PhotographyTips
    SCHEMA = RubyLLM::Schema.create do
      string :time_of_day, description: "Best time of day to photograph this species"
      string :approach, description: "How to approach without disturbing the bird"
      string :settings, description: "Recommended camera settings (shutter speed, aperture, ISO)"
      string :habitat, description: "Where to find this species for photography"
    end

    def initialize(species:, common_name:)
      @species = species
      @common_name = common_name
    end

    def fetch
      Instrumentation.instrument("photography_tips.feather", { species: @species, common_name: @common_name }) do
        chat = RubyLLM.chat(model: "claude-haiku-4")
        chat.with_schema(SCHEMA)
        parsed = chat.ask(prompt).content
        {
          time_of_day: parsed["time_of_day"],
          approach: parsed["approach"],
          settings: parsed["settings"],
          habitat: parsed["habitat"],
        }
      end
    end

    private

    def prompt
      "Provide concise bird photography tips for #{@common_name} (#{@species}). " \
        "Include best time of day, how to approach, recommended camera settings, and ideal habitat for photography."
    end
  end
end

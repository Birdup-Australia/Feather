# frozen_string_literal: true

module FeatherAi
  # Generates photography tips for identified bird species.
  class PhotographyTips
    SCHEMA = RubyLLM::Schema.create do
      string :time_of_day, description: "Best time of day to photograph this species"
      string :approach, description: "How to approach without disturbing the bird"
      string :settings, description: "Recommended camera settings (shutter speed, aperture, ISO)"
      string :habitat, description: "Where to find this species for photography"
    end

    def initialize(species:, common_name:, config: FeatherAi.configuration)
      @species = species
      @common_name = common_name
      @config = config
    end

    def fetch
      Instrumentation.instrument("photography_tips.feather_ai", instrumentation_payload) do
        parsed = fetch_from_llm
        build_tips_hash(parsed)
      end
    end

    private

    def instrumentation_payload
      { species: @species, common_name: @common_name }
    end

    def fetch_from_llm
      chat = RubyLLM.chat(model: @config.tips_model)
      chat.with_schema(SCHEMA)
      chat.ask(prompt).content
    end

    def build_tips_hash(parsed)
      {
        time_of_day: parsed["time_of_day"],
        approach: parsed["approach"],
        settings: parsed["settings"],
        habitat: parsed["habitat"]
      }
    end

    def prompt
      "Provide concise bird photography tips for #{@common_name} (#{@species}). " \
        "Include best time of day, how to approach, recommended camera settings, and ideal habitat for photography."
    end
  end
end

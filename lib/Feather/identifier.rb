# frozen_string_literal: true

module Feather
  class Identifier
    SCHEMA = RubyLLM::Schema.define do
      property :common_name, type: :string, description: "Common name of the bird"
      property :species, type: :string, description: "Scientific species name (Genus species)"
      property :family, type: :string, description: "Bird family name"
      property :confidence, type: :string, enum: ["high", "medium", "low"], description: "Identification confidence"
      property :region_native, type: :boolean, description: "Whether this species is native to the given region"
    end

    def initialize(config: Feather.configuration)
      @config = config
    end

    def identify(image = nil, audio = nil, location: nil)
      raise ArgumentError, "At least one of image or audio must be provided" if image.nil? && audio.nil?

      effective_location = location || @config.location
      chat = RubyLLM.chat(model: @config.model)
      chat.with_instructions(system_prompt(effective_location))

      message = build_message(image, audio)
      response = chat.ask(message)
      parsed = response.structured(SCHEMA)

      tips_loader = -> { PhotographyTips.new(species: parsed.species, common_name: parsed.common_name).fetch }

      Result.new(
        common_name: parsed.common_name,
        species: parsed.species,
        family: parsed.family,
        confidence: parsed.confidence,
        region_native: parsed.region_native,
        photography_tips_loader: tips_loader,
      )
    end

    private

    def system_prompt(location)
      base = "You are an expert ornithologist. Identify the bird from the provided image and/or audio. " \
             "Return structured identification data."
      return base unless location

      "#{base} The observer is located in #{location} — prioritize species native to that region."
    end

    def build_message(image, audio)
      parts = []

      if image
        parts << { type: :image, content: image }
      end

      if audio
        transcript = RubyLLM.transcribe(audio)
        parts << { type: :text, content: "Bird call/song transcript: #{transcript}" }
      end

      parts << { type: :text, content: "Identify the bird shown and/or heard above." }

      parts
    end
  end
end

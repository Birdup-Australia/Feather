# frozen_string_literal: true

module Feather
  class Identifier
    SCHEMA = RubyLLM::Schema.create do
      string :common_name, description: "Common name of the bird"
      string :species, description: "Scientific species name (Genus species)"
      string :family, description: "Bird family name"
      string :confidence, description: "Identification confidence: high, medium, or low"
      boolean :region_native, description: "Whether this species is native to the given region"
    end

    def initialize(config: Feather.configuration)
      @config = config
    end

    def identify(image = nil, audio = nil, location: nil)
      raise ArgumentError, "At least one of image or audio must be provided" if image.nil? && audio.nil?

      effective_location = location || @config.location
      source = derive_source(image, audio)
      payload = { model: @config.model, location: effective_location, has_image: !image.nil?, has_audio: !audio.nil? }

      Instrumentation.instrument("identify.feather", payload) do
        chat = RubyLLM.chat(model: @config.model)
        chat.with_instructions(system_prompt(effective_location))
        chat.with_schema(SCHEMA)

        message = build_message(image, audio)

        start_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        response = chat.ask(message)
        duration_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms

        parsed = response.content

        tips_loader = -> { PhotographyTips.new(species: parsed["species"], common_name: parsed["common_name"]).fetch }

        result = Result.new(
          common_name: parsed["common_name"],
          species: parsed["species"],
          family: parsed["family"],
          confidence: parsed["confidence"],
          region_native: parsed["region_native"],
          photography_tips_loader: tips_loader,
          model_id: response.model_id,
          input_tokens: response.input_tokens,
          output_tokens: response.output_tokens,
          cost: compute_cost(response.input_tokens, response.output_tokens),
          duration_ms: duration_ms,
          source: source,
        )

        payload[:result] = result
        result
      end
    end

    private

    def derive_source(image, audio)
      if image && audio
        :multimodal
      elsif image
        :vision
      else
        :audio
      end
    end

    # Returns a USD cost estimate based on token counts, or nil when the count
    # is unavailable or the configured provider has no rate table defined here.
    # Use your provider's dashboard for billing accuracy — these are estimates.
    PROVIDER_RATES = {
      # Approximate mid-2025 rates (USD per 1M tokens).
      anthropic: { input: 3.00, output: 15.00 },
    }.freeze

    def compute_cost(input_tokens, output_tokens)
      return nil if input_tokens.nil? || output_tokens.nil?

      rates = PROVIDER_RATES[@config.provider]
      return nil if rates.nil?

      ((input_tokens * rates[:input]) + (output_tokens * rates[:output])) / 1_000_000.0
    end

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

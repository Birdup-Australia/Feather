# frozen_string_literal: true

module FeatherAi
  # Core bird identification using LLM vision and audio transcription.
  # rubocop:disable Metrics/ClassLength
  class Identifier
    SCHEMA = RubyLLM::Schema.create do
      string :common_name, description: "Common name of the bird"
      string :species, description: "Scientific species name (Genus species)"
      string :family, description: "Bird family name"
      string :confidence, description: "Identification confidence: high, medium, or low"
      boolean :region_native, description: "Whether this species is native to the given region"
    end

    # Approximate mid-2025 rates (USD per 1M tokens).
    # Use your provider's dashboard for billing accuracy — these are estimates.
    PROVIDER_RATES = {
      anthropic: { input: 3.00, output: 15.00 }
    }.freeze

    def initialize(config: FeatherAi.configuration)
      @config = config
    end

    def identify(image = nil, audio = nil, location: nil)
      validate_inputs!(image, audio)

      effective_location = location || @config.location
      source = derive_source(image, audio)
      payload = instrumentation_payload(effective_location, image, audio)

      Instrumentation.instrument("identify.feather_ai", payload) do
        response, duration_ms = perform_identification(image, audio, effective_location)
        result = build_result(response, duration_ms, source)
        payload[:result] = result
        result
      end
    end

    private

    def validate_inputs!(image, audio)
      return unless image.nil? && audio.nil?

      raise FeatherAi::ConfigurationError, "At least one of image or audio must be provided"
    end

    def instrumentation_payload(location, image, audio)
      {
        model: @config.model,
        location: location,
        has_image: !image.nil?,
        has_audio: !audio.nil?
      }
    end

    def perform_identification(image, audio, location)
      chat = configure_chat(location)
      message = build_message(image, audio)

      start_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
      response = chat.ask(message)
      duration_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_ms

      [response, duration_ms]
    end

    def configure_chat(location)
      chat = RubyLLM.chat(model: @config.model)
      chat.with_instructions(system_prompt(location))
      chat.with_schema(SCHEMA)
      chat
    end

    def build_result(response, duration_ms, source)
      parsed = response.content
      Result.new(
        **parsed_identification_attrs(parsed),
        **response_observability_attrs(response, duration_ms, source)
      )
    end

    def parsed_identification_attrs(parsed)
      {
        common_name: parsed["common_name"],
        species: parsed["species"],
        family: parsed["family"],
        confidence: parsed["confidence"],
        region_native: parsed["region_native"],
        photography_tips_loader: tips_loader(parsed)
      }
    end

    def response_observability_attrs(response, duration_ms, source)
      {
        model_id: response.model_id,
        input_tokens: response.input_tokens,
        output_tokens: response.output_tokens,
        cost: compute_cost(response.input_tokens, response.output_tokens),
        duration_ms: duration_ms,
        source: source
      }
    end

    def tips_loader(parsed)
      lambda {
        PhotographyTips.new(
          species: parsed["species"],
          common_name: parsed["common_name"],
          config: @config
        ).fetch
      }
    end

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

      parts << { type: :image, content: image } if image

      if audio
        transcript = RubyLLM.transcribe(audio)
        parts << { type: :text, content: "Bird call/song transcript: #{transcript}" }
      end

      parts << { type: :text, content: "Identify the bird shown and/or heard above." }

      parts
    end
  end
  # rubocop:enable Metrics/ClassLength
end

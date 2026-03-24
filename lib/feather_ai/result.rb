# frozen_string_literal: true

module FeatherAi
  # Immutable value object wrapping all identification output.
  class Result
    attr_reader :common_name, :species, :family, :confidence, :region_native, :reasoning, :candidates,
                :input_tokens, :output_tokens, :cost, :model_id, :duration_ms, :source,
                :consensus_models

    def initialize(attrs = {})
      assign_identification_attrs(attrs)
      assign_photography_attrs(attrs)
      assign_observability_attrs(attrs)
    end

    def confident?
      @confidence == :high
    end

    def region_native?
      @region_native == true
    end

    def photography_tips
      return @photography_tips_data if defined?(@photography_tips_loaded)

      @photography_tips_loaded = true
      @photography_tips_data = @photography_tips_loader&.call
    end

    def to_h
      identification_hash
        .merge(observability_hash)
        .merge(photography_hash)
    end

    private

    def assign_identification_attrs(attrs)
      @common_name = attrs[:common_name]
      @species = attrs[:species]
      @family = attrs[:family]
      @confidence = attrs[:confidence]&.to_sym
      @region_native = attrs[:region_native]
      @reasoning = attrs[:reasoning]
      @candidates = attrs[:candidates] || []
    end

    def assign_photography_attrs(attrs)
      @photography_tips_loader = attrs[:photography_tips_loader]
      @photography_tips_data = attrs[:photography_tips]
      @photography_tips_loaded = true if attrs.key?(:photography_tips)
    end

    def assign_observability_attrs(attrs)
      @input_tokens = attrs[:input_tokens]
      @output_tokens = attrs[:output_tokens]
      @cost = attrs[:cost]
      @model_id = attrs[:model_id]
      @duration_ms = attrs[:duration_ms]
      @source = attrs[:source]
      @consensus_models = attrs[:consensus_models]
    end

    def identification_hash
      {
        reasoning: @reasoning,
        common_name: @common_name,
        species: @species,
        family: @family,
        confidence: @confidence,
        confident: confident?,
        region_native: region_native?,
        candidates: @candidates
      }
    end

    def observability_hash
      {
        model_id: @model_id,
        input_tokens: @input_tokens,
        output_tokens: @output_tokens,
        cost: @cost,
        duration_ms: @duration_ms,
        source: @source,
        consensus_models: @consensus_models
      }
    end

    def photography_hash
      { photography_tips: photography_tips }
    end
  end
end

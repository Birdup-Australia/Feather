# frozen_string_literal: true

module Feather
  module SpecHelpers
    def build_result(overrides = {})
      Feather::Result.new({
        common_name: "Splendid Fairywren",
        species: "Malurus splendens",
        family: "Maluridae",
        confidence: :high,
        region_native: true,
        model_id: "claude-sonnet-4-6",
        input_tokens: 512,
        output_tokens: 64,
        cost: 0.00192,
        duration_ms: 300,
        source: :vision,
      }.merge(overrides))
    end
  end
end

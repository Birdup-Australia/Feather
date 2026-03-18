# frozen_string_literal: true

module Feather
  class Consensus
    def initialize(config: Feather.configuration)
      @config = config
      @models = config.consensus_models
    end

    def identify(image = nil, audio = nil, location: nil)
      payload = { models: @models, location: location || @config.location }

      Instrumentation.instrument("consensus.feather", payload) do
        # NOTE: models are queried sequentially. The two LLM calls are independent
        # and could be parallelised (e.g. with threads) to halve wall-clock latency
        # if that becomes important for your use case.
        results = @models.map do |model|
          config_for_model = config_with_model(model)
          Identifier.new(config: config_for_model).identify(image, audio, location: location)
        end

        result = if agree?(results)
          primary = results.first
          Result.new(
            common_name: primary.common_name,
            species: primary.species,
            family: primary.family,
            confidence: :high,
            region_native: primary.region_native?,
            photography_tips_loader: -> { PhotographyTips.new(species: primary.species, common_name: primary.common_name).fetch },
          )
        else
          agreed_family = results.map(&:family).uniq.length == 1 ? results.first.family : nil
          Result.new(
            common_name: nil,
            species: nil,
            family: agreed_family,
            confidence: :low,
            region_native: false,
            candidates: results,
          )
        end

        payload[:agreed] = result.confident?
        payload[:result] = result
        result
      end
    end

    private

    def agree?(results)
      results.map { |r| r.species&.strip&.downcase }.uniq.length == 1
    end

    def config_with_model(model)
      dup_config = @config.dup
      dup_config.model = model
      dup_config
    end
  end
end

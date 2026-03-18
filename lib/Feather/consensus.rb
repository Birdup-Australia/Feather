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

        total_input_tokens  = sum_field(results, :input_tokens)
        total_output_tokens = sum_field(results, :output_tokens)
        # Sum of per-model wall-clock durations (total model time, not caller latency).
        total_duration_ms   = sum_field(results, :duration_ms)
        total_cost          = sum_field(results, :cost)

        shared_attrs = {
          consensus_models: @models,
          input_tokens: total_input_tokens,
          output_tokens: total_output_tokens,
          duration_ms: total_duration_ms,
          cost: total_cost,
          source: results.first&.source,
        }

        result = if agree?(results)
          primary = results.first
          Result.new(
            **shared_attrs,
            common_name: primary.common_name,
            species: primary.species,
            family: primary.family,
            confidence: :high,
            region_native: primary.region_native?,
            model_id: primary.model_id,
            photography_tips_loader: -> { PhotographyTips.new(species: primary.species, common_name: primary.common_name).fetch },
          )
        else
          agreed_family = results.map(&:family).uniq.length == 1 ? results.first.family : nil
          Result.new(
            **shared_attrs,
            common_name: nil,
            species: nil,
            family: agreed_family,
            confidence: :low,
            region_native: false,
            model_id: nil,
            candidates: results,
          )
        end

        payload[:agreed] = result.confident?
        payload[:result] = result
        result
      end
    end

    private

    def sum_field(results, field)
      values = results.map(&field)
      values.any?(&:nil?) ? nil : values.sum
    end

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

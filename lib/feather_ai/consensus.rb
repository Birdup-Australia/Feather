# frozen_string_literal: true

module FeatherAi
  # Multi-model consensus identification to improve accuracy.
  class Consensus
    def initialize(config: FeatherAi.configuration)
      @config = config
      @models = config.consensus_models
    end

    def identify(image = nil, audio = nil, location: nil)
      payload = { models: @models, location: location || @config.location }

      Instrumentation.instrument("consensus.feather_ai", payload) do
        results = fetch_results_from_models(image, audio, location)
        shared_attrs = aggregate_metrics(results)
        result = build_consensus_result(results, shared_attrs)

        payload[:agreed] = result.confident?
        payload[:result] = result
        result
      end
    end

    private

    def fetch_results_from_models(image, audio, location)
      @models.map do |model|
        config_for_model = config_with_model(model)
        Thread.new { Identifier.new(config: config_for_model).identify(image, audio, location: location) }
      end.map(&:value)
    end

    def aggregate_metrics(results)
      {
        consensus_models: @models,
        input_tokens: sum_field(results, :input_tokens),
        output_tokens: sum_field(results, :output_tokens),
        duration_ms: sum_field(results, :duration_ms),
        cost: sum_field(results, :cost),
        source: results.first&.source
      }
    end

    def build_consensus_result(results, shared_attrs)
      if agree?(results)
        build_agreed_result(results.first, shared_attrs)
      else
        build_disagreed_result(results, shared_attrs)
      end
    end

    def build_agreed_result(primary, shared_attrs)
      Result.new(**shared_attrs, **agreed_result_attrs(primary))
    end

    def build_disagreed_result(results, shared_attrs)
      Result.new(**shared_attrs, **disagreed_result_attrs(results))
    end

    def agreed_result_attrs(primary)
      {
        common_name: primary.common_name,
        species: primary.species,
        family: primary.family,
        confidence: :high,
        region_native: primary.region_native?,
        model_id: primary.model_id,
        photography_tips_loader: tips_loader_for(primary)
      }
    end

    def disagreed_result_attrs(results)
      {
        common_name: nil,
        species: nil,
        family: calculate_agreed_family(results),
        confidence: :low,
        region_native: false,
        model_id: nil,
        candidates: results
      }
    end

    def tips_loader_for(primary)
      config = @config
      lambda {
        PhotographyTips.new(
          species: primary.species,
          common_name: primary.common_name,
          config: config
        ).fetch
      }
    end

    def calculate_agreed_family(results)
      results.map(&:family).uniq.length == 1 ? results.first.family : nil
    end

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

# frozen_string_literal: true

module Feather
  # Configuration object for Feather gem settings.
  class Configuration
    attr_accessor :provider, :model, :location, :consensus_models, :tips_model

    def initialize
      @provider = :anthropic
      @model = "claude-sonnet-4"
      @location = nil
      @consensus_models = %w[claude-sonnet-4 claude-haiku-4]
      @tips_model = "claude-haiku-4"
    end

    def initialize_copy(source)
      super
      @consensus_models = source.consensus_models.dup
    end
  end
end

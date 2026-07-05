# frozen_string_literal: true

module FeatherAi
  # Configuration object for FeatherAi gem settings.
  class Configuration
    attr_accessor :provider, :model, :location, :consensus_models, :tips_model, :media_resolution, :tools

    def initialize
      @provider = :anthropic
      @model = "claude-sonnet-4-5"
      @location = nil
      @consensus_models = %w[claude-sonnet-4-5 claude-haiku-4-5]
      @tips_model = "claude-haiku-4-5"
      @media_resolution = :high
      @tools = []
    end

    def initialize_copy(source)
      super
      @consensus_models = source.consensus_models.dup
      @tools = source.tools.dup
    end
  end
end

# frozen_string_literal: true

module Feather
  class Configuration
    attr_accessor :provider, :model, :location, :consensus_models

    def initialize
      @provider = :anthropic
      @model = "claude-sonnet-4"
      @location = nil
      @consensus_models = ["claude-sonnet-4", "claude-haiku-4"]
    end
  end
end

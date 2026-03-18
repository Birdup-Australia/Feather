# frozen_string_literal: true

require "ruby_llm"
require "ruby_llm/schema"

require_relative "feather/version"
require_relative "feather/configuration"
require_relative "feather/instrumentation"
require_relative "feather/result"
require_relative "feather/photography_tips"
require_relative "feather/identifier"
require_relative "feather/consensus"

module Feather
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class IdentificationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset!
      @configuration = nil
    end

    def identify(image = nil, audio = nil, location: nil, consensus: false)
      if consensus
        Consensus.new.identify(image, audio, location: location)
      else
        Identifier.new.identify(image, audio, location: location)
      end
    end
  end
end

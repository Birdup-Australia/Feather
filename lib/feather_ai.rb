# frozen_string_literal: true

require "ruby_llm"
require "ruby_llm/schema"

require_relative "feather_ai/version"
require_relative "feather_ai/configuration"
require_relative "feather_ai/instrumentation"
require_relative "feather_ai/result"
require_relative "feather_ai/photography_tips"
require_relative "feather_ai/identifier"
require_relative "feather_ai/consensus"

# Top-level module for bird identification using LLMs.
module FeatherAi
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

    # Identify a bird from image(s) and/or audio.
    # @param image [String, Array<String>, nil] path(s) to image file(s)
    # @param audio [String, nil] path to audio file
    def identify(image = nil, audio = nil, location: nil, consensus: false)
      if consensus
        Consensus.new.identify(image, audio, location: location)
      else
        Identifier.new.identify(image, audio, location: location)
      end
    end
  end
end

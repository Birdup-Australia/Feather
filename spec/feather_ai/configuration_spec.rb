# frozen_string_literal: true

RSpec.describe FeatherAi::Configuration do
  subject(:config) { described_class.new }

  # The other specs stub RubyLLM, so this is the only check that the shipped defaults
  # are models the installed RubyLLM can actually resolve (and therefore price).
  it "defaults to models in RubyLLM's bundled registry" do
    ids = [config.model, *config.consensus_models, config.tips_model].uniq

    expect { ids.each { |id| RubyLLM.models.find(id) } }.not_to raise_error
  end
end

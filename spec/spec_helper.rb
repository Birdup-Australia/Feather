# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "feather"
require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV["ANTHROPIC_API_KEY"] }
  config.filter_sensitive_data("<OPENAI_API_KEY>") { ENV["OPENAI_API_KEY"] }
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    Feather.instance_variable_set(:@configuration, nil)
  end
end

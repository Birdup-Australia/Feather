# frozen_string_literal: true

require_relative "lib/feather_ai/version"

Gem::Specification.new do |spec|
  spec.name = "feather-ai"
  spec.version = FeatherAi::VERSION
  spec.authors = ["Brandyn Britton"]
  spec.email = ["brandynbb96@gmail.com"]

  spec.summary = "Identify birds from photos and audio using LLMs"
  spec.description = "A Ruby gem for identifying birds from photos and audio using RubyLLM. " \
                     "Adds multi-modal identification, location-aware results, multi-model consensus, " \
                     "and a Rails integration."
  spec.homepage = "https://github.com/Birdup-Australia/Feather"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_llm", "~> 1.0"
end

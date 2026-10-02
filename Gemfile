# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in Feather.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

# These transitive gems dropped Ruby 3.2 in their latest majors; keep the lockfile installable on the 3.2 CI job
gem "marcel", "< 2"
gem "parallel", "< 2"
gem "rbs", "< 4"

gem "rspec", "~> 3.0"
gem "rubocop", "~> 1.21"
gem "rubocop-rspec", "~> 3.0"

gem "vcr", "~> 6.0"
gem "webmock", "~> 3.0"

gem "simplecov", "~> 0.22", require: false

# frozen_string_literal: true

require 'bundler/setup'
require 'wcc/contentful'
require 'wcc/contentful/redirect'
require 'vcr'

require 'fixtures_helper'
require 'bench_helper'

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  Time.zone ||= 'Central Time (US & Canada)'

  config.filter_run_excluding bench: true

  config.include FixturesHelper
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.ignore_localhost = true
  c.hook_into :webmock
  c.default_cassette_options = { record: :once }
  c.filter_sensitive_data('<CONTENTFUL_ACCESS_TOKEN>') { '<ACTUAL_CONTENTFUL_ACCESS_TOKEN>' }
  c.filter_sensitive_data('<CONTENTFUL_SPACE_ID>') { '<ACTUAL_CONTENTFUL_SPACE_ID>' }
  c.filter_sensitive_data('<CONTENTFUL_MANAGEMENT_TOKEN>') { '<ACTUAL_CONTENTFUL_MANAGEMENT_TOKEN>' }
end

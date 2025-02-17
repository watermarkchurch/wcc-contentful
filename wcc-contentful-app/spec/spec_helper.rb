# frozen_string_literal: true

require 'logger'
require 'simplecov'

SimpleCov.start do
  root File.expand_path('../..', __dir__)
  add_filter '/spec/'
  coverage_dir "#{File.expand_path('..', __dir__)}/coverage"
end

require 'bundler/setup'
require 'dotenv/load'
require 'wcc/contentful'
require 'webmock/rspec'
require 'vcr'
require 'httplog'
require 'wcc/contentful/rspec'

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.shared_context 'Contentful config' do
  let(:contentful_access_token) { ENV.fetch('CONTENTFUL_ACCESS_TOKEN', 'test1234') }
  let(:contentful_management_token) { ENV.fetch('CONTENTFUL_MANAGEMENT_TOKEN', 'CFPAT-test1234') }
  let(:contentful_preview_token) { ENV.fetch('CONTENTFUL_PREVIEW_TOKEN', 'test123456') }
  let(:contentful_space_id) { ENV.fetch('CONTENTFUL_SPACE_ID', 'test1xab') }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.
  #   # This allows you to limit a spec run to individual examples or groups
  #   # you care about by tagging them with `:focus` metadata. When nothing
  #   # is tagged with `:focus`, all examples get run. RSpec also provides
  #   # aliases for `it`, `describe`, and `context` that include `:focus`
  #   # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  config.filter_run_when_matching :focus

  Time.zone ||= 'Central Time (US & Canada)'

  config.include FixturesHelper
  config.include_context 'Contentful config'
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.ignore_localhost = true
  c.hook_into :webmock
  c.default_cassette_options = { record: :none }
  c.filter_sensitive_data('<CONTENTFUL_ACCESS_TOKEN>') { ENV.fetch('CONTENTFUL_ACCESS_TOKEN', 'test1234') }
  c.filter_sensitive_data('<CONTENTFUL_SPACE_ID>') { ENV.fetch('CONTENTFUL_SPACE_ID', 'test1xab') }
  c.filter_sensitive_data('<CONTENTFUL_MANAGEMENT_TOKEN>') {
    ENV.fetch('CONTENTFUL_MANAGEMENT_TOKEN', 'CFPAT-test1234')
  }
  c.configure_rspec_metadata!
end

HttpLog.configure do |config|
  config.compact_log = true
end

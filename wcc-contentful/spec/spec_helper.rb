# frozen_string_literal: true

require 'simplecov'
require 'logger'

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
require 'wisper/rspec/matchers'
require 'rspec-instrumentation-matcher'

require 'bench_helper'

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.shared_context 'Contentful config' do
  let(:contentful_access_token) { ENV.fetch('CONTENTFUL_ACCESS_TOKEN', 'test1234') }
  let(:contentful_management_token) { ENV.fetch('CONTENTFUL_MANAGEMENT_TOKEN', 'CFPAT-test1234') }
  let(:contentful_preview_token) { ENV.fetch('CONTENTFUL_PREVIEW_TOKEN', 'test123456') }
  let(:contentful_space_id) { ENV.fetch('CONTENTFUL_SPACE_ID', 'test1xab') }

  def contentful_reset!
    WCC::Contentful.instance_variable_set('@initialized', nil)
    WCC::Contentful::Services.instance_variable_set(:@singleton__instance__, nil)

    # clean out everything in the WCC::Contentful::Model generated namespace
    consts = WCC::Contentful::Model.constants(false).map(&:to_s).uniq
    consts.each do |c|
      WCC::Contentful::Model.send(:remove_const, c.split(':').last)
    rescue StandardError => e
      warn e
    end
    WCC::Contentful::Model.instance_variable_get('@registry').clear

    WCC::Contentful::Model.instance_variable_set('@schema', nil)
    WCC::Contentful::Model.instance_variable_set('@services', nil)
    WCC::Contentful::Model.instance_variable_set('@configuration', nil)
    Wisper.clear
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  Time.zone ||= 'Central Time (US & Canada)'

  config.filter_run_excluding bench: true

  config.include FixturesHelper
  config.include WCC::Contentful::SnapshotHelper
  config.include_context 'Contentful config'
  config.include(Wisper::RSpec::BroadcastMatcher)

  WCC::Contentful::SyncEngine::Job.queue_adapter = :test if defined?(WCC::Contentful::SyncEngine::Job)

  config.before(:each) do
    WCC::Contentful.instance_variable_set('@configuration', nil)

    contentful_reset!
  end
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

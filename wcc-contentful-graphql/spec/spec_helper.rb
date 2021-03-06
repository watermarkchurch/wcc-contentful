# frozen_string_literal: true

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
require 'httplog'

require 'bench_helper'

Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.shared_context 'Contentful config' do
  let(:contentful_access_token) { ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234' }
  let(:contentful_management_token) { ENV['CONTENTFUL_MANAGEMENT_TOKEN'] || 'CFPAT-test1234' }
  let(:contentful_preview_token) { ENV['CONTENTFUL_PREVIEW_TOKEN'] || 'test123456' }
  let(:contentful_space_id) { ENV['CONTENTFUL_SPACE_ID'] || 'test1xab' }
end

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
  config.include_context 'Contentful config'

  config.before(:each) do
    WCC::Contentful.instance_variable_set('@configuration', nil)
    WCC::Contentful.instance_variable_set('@initialized', nil)
    WCC::Contentful::Services.instance_variable_set(:@singleton__instance__, nil)

    # clean out everything in the WCC::Contentful::Model generated namespace
    consts = WCC::Contentful::Model.constants(false).map(&:to_s).uniq
    consts.each do |c|
      begin
        WCC::Contentful::Model.send(:remove_const, c.split(':').last)
      rescue StandardError => e
        warn e
      end
    end
    WCC::Contentful::Model.class_variable_get('@@registry').clear
  end
end

HttpLog.configure do |config|
  config.compact_log = true
end

# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'httplog'

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

  config.include FixturesHelper
  config.include_context 'Contentful config'
end

HttpLog.configure do |config|
  config.compact_log = true
  config.color = true
end

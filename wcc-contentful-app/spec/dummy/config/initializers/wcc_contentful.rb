# frozen_string_literal: true

require 'wcc/contentful/app/rails'

WCC::Contentful::App.configure do |config|
  # Required
  config.access_token = ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234'
  config.space = ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'
  config.management_token = ENV['CONTENTFUL_MANAGEMENT_TOKEN'] || 'CFPAT-test1234'
  config.default_locale = 'en-US'

  config.webhook_username = 'tester1'
  config.webhook_password = 'password1'

  config.preview_password = 'test-preview-pw'

  # Optional
  # config.management_token = # Contentful API management token
  # config.store = # :direct, :eager_sync, or :lazy_sync

  config.update_schema_file = :never
end

# Download content types, build models, and sync content
WCC::Contentful::App.init!

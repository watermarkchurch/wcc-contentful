# frozen_string_literal: true

require 'wcc/contentful/app/rails'

WCC::Contentful.configure do |config|
  # Required
  config.access_token = ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234'
  config.space = ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'
  config.management_token = ENV['CONTENTFUL_MANAGEMENT_TOKEN'] || 'CFPAT-test1234'
  config.default_locale = 'en-US'

  config.webhook_username = 'tester1'
  config.webhook_password = 'password1'

  # Optional
  # config.management_token = # Contentful API management token
  # config.content_delivery = # :direct, :eager_sync, or :lazy_sync
  # config.sync_store = # :memory, :postgres, or a custom implementation
end

# Download content types, build models, and sync content
WCC::Contentful.init!
WCC::Contentful::App.init!

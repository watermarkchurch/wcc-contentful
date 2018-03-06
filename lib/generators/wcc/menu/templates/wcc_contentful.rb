
WCC::Contentful.configure do |config|
  # Required
  config.access_token = # Contentful CDN access token
  config.space = # Contentful Space ID

  # Optional
  config.management_token = # Contentful API management token
  config.default_locale = # Set default locale, if left blank this is 'en-US'
  config.content_delivery = # :direct, :eager_sync, or :lazy_sync
  config.sync_store = # :memory, :postgres, or a custom implementation
end

# Download content types, build models, and sync content
WCC::Contentful.init!
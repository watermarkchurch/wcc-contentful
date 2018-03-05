# frozen_string_literal: true

class WCC::Contentful::Configuration
  ATTRIBUTES = %i[
    access_token
    management_token
    space
    default_locale
    content_delivery
  ].freeze
  attr_accessor(*ATTRIBUTES)

  CDN_METHODS = [
    :eager_sync,
    # TODO: :lazy_sync
    :direct
  ].freeze

  SYNC_STORES = {
    memory: ->(_config) { WCC::Contentful::Store::MemoryStore.new },
    postgres: ->(_config) { WCC::Contentful::Store::PostgresStore.new }
  }.freeze

  def content_delivery=(symbol)
    raise ArgumentError, "Please set one of #{CDN_METHODS}" unless CDN_METHODS.include?(symbol)
    @content_delivery = symbol
  end

  def sync_store=(symbol)
    if symbol.is_a? Symbol
      unless SYNC_STORES.keys.include?(symbol)
        raise ArgumentError, "Please use one of #{SYNC_STORES.keys}"
      end
    end
    @sync_store = symbol
  end

  def sync_store
    @sync_store = SYNC_STORES[@sync_store].call(self) if @sync_store.is_a? Symbol
    @sync_store ||= Store::MemoryStore.new
  end

  def client
    @client ||=
      if defined?(ContentfulModel)
        configuration.configure_contentful_model
        @client = ContentfulModel::Base.client
      else
        @client = Contentful::Client.new(
          space: configuration.space,
          access_token: configuration.access_token
        )
      end
  end

  def initialize
    @access_token = ''
    @management_token = ''
    @space = ''
    @default_locale = 'en-US'
    @content_delivery = :direct
    @sync_store = :memory
  end

  def configure_contentful_model
    ContentfulModel.configure do |config|
      config.access_token = access_token
      config.management_token = management_token if management_token.present?
      config.space = space
      config.default_locale = default_locale
    end
    @client = ContentfulModel::Base.client
  end
end

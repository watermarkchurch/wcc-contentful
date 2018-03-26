# frozen_string_literal: true

class WCC::Contentful::Configuration
  ATTRIBUTES = %i[
    access_token
    management_token
    space
    default_locale
    content_delivery
    override_get_http
    sync_cache_store
    webhook_username
    webhook_password
  ].freeze
  attr_accessor(*ATTRIBUTES)

  CDN_METHODS = %i[
    eager_sync
    lazy_sync
    direct
  ].freeze

  SYNC_STORES = {
    memory: ->(_config) { WCC::Contentful::Store::MemoryStore.new },
    postgres: ->(_config) {
      require_relative 'store/postgres_store'
      WCC::Contentful::Store::PostgresStore.new(ENV['POSTGRES_CONNECTION'])
    }
  }.freeze

  ##
  # Defines the method by which content is downloaded from the Contentful CDN.
  #
  # [:direct] `config.content_delivery = :direct`
  #           with the `:direct` method, all queries result in web requests to
  #           'https://cdn.contentful.com' via the
  #           {SimpleClient}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn]
  #
  # [:eager_sync] `config.content_delivery = :eager_sync`
  #               with the `:eager_sync` method, the entire content of the Contentful
  #               space is downloaded locally and stored in the
  #               {Sync Store}[rdoc-ref:WCC::Contentful.store].  The application is responsible
  #               to periodically call `WCC::Contentful.sync!` to keep the store updated.
  #               Alternatively, the provided {Engine}[WCC::Contentful::Engine]
  #               can be mounted to receive a webhook from the Contentful space
  #               on publish events:
  #                 mount WCC::Contentful::Engine, at: '/wcc/contentful'
  #
  # [:lazy_sync] `config.content_delivery = :lazy_sync
  #              The `:lazy_sync` method is a hybrid between the other two methods.
  #              Frequently accessed data is stored in an ActiveSupport::Cache implementation
  #              and is kept up-to-date via the Sync API.  Any data that is not present
  #              in the cache is fetched from the CDN like in the `:direct` method.
  #              The application is still responsible to periodically call `sync!`
  #              or to mount the provided Engine.
  #
  def content_delivery=(symbol)
    raise ArgumentError, "Please set one of #{CDN_METHODS}" unless CDN_METHODS.include?(symbol)
    @content_delivery = symbol
  end

  ##
  # Sets the local store which is used with the `:eager_sync` content delivery method.
  # This can be one of `:memory`, `:postgres`, or a custom implementation.
  def sync_store=(symbol)
    if symbol.is_a? Symbol
      unless SYNC_STORES.keys.include?(symbol)
        raise ArgumentError, "Please use one of #{SYNC_STORES.keys}"
      end
    end
    @sync_store = symbol
  end

  ##
  # Initializes the configured Sync Store.
  def sync_store
    @sync_store = SYNC_STORES[@sync_store].call(self) if @sync_store.is_a? Symbol
    @sync_store ||= Store::MemoryStore.new
  end

  def sync_cache_store
    ActiveSupport::Cache.lookup_store(@sync_cache_store)
  end

  # A proc which overrides the "get_http" function in Contentful::Client.
  # All interaction with Contentful will go through this function.
  # Should be a lambda like: ->(url, query, headers = {}, proxy = {}) { ... }
  attr_writer :override_get_http

  def initialize
    @access_token = ''
    @management_token = ''
    @space = ''
    @default_locale = nil
    @content_delivery = :direct
    @sync_store = :memory
  end

  ##
  # Gets a {CDN Client}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn] which provides
  # methods for getting and paging raw JSON data from the Contentful CDN.
  attr_reader :client
  attr_reader :management_client

  ##
  # Called by WCC::Contentful.init! to configure the
  # Contentful clients.  This method can be called independently of `init!` if
  # the application would prefer not to generate all the models.
  #
  # If the {contentful.rb}[https://github.com/contentful/contentful.rb] gem is
  # loaded, it is extended to make use of the `override_get_http` lambda.
  def configure_contentful
    @client = nil
    @management_client = nil

    if defined?(::ContentfulModel)
      ContentfulModel.configure do |config|
        config.access_token = access_token
        config.management_token = management_token if management_token.present?
        config.space = space
        config.default_locale = default_locale || 'en-US'
      end
    end

    require_relative 'client_ext' if defined?(::Contentful)

    @client = WCC::Contentful::SimpleClient::Cdn.new(
      access_token: access_token,
      space: space,
      default_locale: default_locale
    )
    return unless management_token.present?
    @management_client = WCC::Contentful::SimpleClient::Management.new(
      management_token: management_token,
      space: space,
      default_locale: default_locale
    )
  end
end

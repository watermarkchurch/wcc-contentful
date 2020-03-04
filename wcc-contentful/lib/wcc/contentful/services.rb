# frozen_string_literal: true

module WCC::Contentful
  class Services
    class << self
      def instance
        @singleton__instance__ ||= new # rubocop:disable Naming/MemoizedInstanceVariableName
      end
    end

    def configuration
      @configuration ||= WCC::Contentful.configuration
    end

    def initialize(configuration = nil)
      @configuration = configuration
    end

    # Gets the data-store which executes the queries run against the dynamic
    # models in the WCC::Contentful::Model namespace.
    # This is one of the following based on the configured content_delivery method:
    #
    # [:direct] an instance of {WCC::Contentful::Store::CDNAdapter} with a
    #           {WCC::Contentful::SimpleClient::Cdn CDN Client} to access the CDN.
    #
    # [:lazy_sync] an instance of {WCC::Contentful::Store::LazyCacheStore}
    #              with the configured ActiveSupport::Cache implementation and a
    #              {WCC::Contentful::SimpleClient::Cdn CDN Client} for when data
    #              cannot be found in the cache.
    #
    # [:eager_sync] an instance of the configured Store type, defined by
    #               {WCC::Contentful::Configuration#sync_store}
    #
    # @api Store
    def store
      @store ||=
        ensure_configured do |config|
          config.store_factory.build_sync_store(self)
        end
    end

    # An instance of {WCC::Contentful::Store::CDNAdapter} which connects to the
    # Contentful Preview API to return preview content.
    #
    # @api Store
    def preview_store
      @preview_store ||=
        ensure_configured do |config|
          WCC::Contentful::Store::Factory.new(
            config,
            :direct,
            :preview
          ).build_sync_store(self)
        end
    end

    # Gets a {WCC::Contentful::SimpleClient::Cdn CDN Client} which provides
    # methods for getting and paging raw JSON data from the Contentful CDN.
    #
    # @api Client
    def client
      @client ||=
        ensure_configured do |config|
          WCC::Contentful::SimpleClient::Cdn.new(
            **config.connection_options,
            access_token: config.access_token,
            space: config.space,
            default_locale: config.default_locale,
            connection: config.connection,
            environment: config.environment
          )
        end
    end

    # Gets a {WCC::Contentful::SimpleClient::Cdn CDN Client} which provides
    # methods for getting and paging raw JSON data from the Contentful Preview API.
    #
    # @api Client
    def preview_client
      @preview_client ||=
        ensure_configured do |config|
          if config.preview_token.present?
            WCC::Contentful::SimpleClient::Preview.new(
              **config.connection_options,
              preview_token: config.preview_token,
              space: config.space,
              default_locale: config.default_locale,
              connection: config.connection,
              environment: config.environment
            )
          end
        end
    end

    # Gets a {WCC::Contentful::SimpleClient::Management Management Client} which provides
    # methods for updating data via the Contentful Management API
    #
    # @api Client
    def management_client
      @management_client ||=
        ensure_configured do |config|
          if config.management_token.present?
            WCC::Contentful::SimpleClient::Management.new(
              **config.connection_options,
              management_token: config.management_token,
              space: config.space,
              default_locale: config.default_locale,
              connection: config.connection,
              environment: config.environment
            )
          end
        end
    end

    # Gets the configured WCC::Contentful::SyncEngine which is responsible for
    # updating the currently configured store.  The application must periodically
    # call #next on this instance.  Alternately, the application can mount the
    # WCC::Contentful::Engine, which will call #next anytime a webhook is received.
    #
    # This returns `nil` if the currently configured store does not respond to sync
    # events.
    def sync_engine
      @sync_engine ||=
        if store.index?
          SyncEngine.new(
            store: store,
            client: client,
            key: 'sync:token'
          )
        end
    end

    # Gets the configured instrumentation adapter, defaulting to ActiveSupport::Notifications
    def instrumentation
      return @instrumentation if @instrumentation
      return ActiveSupport::Notifications if WCC::Contentful.configuration.nil?

      @instrumentation ||=
        WCC::Contentful.configuration.instrumentation_adapter ||
        ActiveSupport::Notifications
    end

    private

    def ensure_configured
      raise StandardError, 'WCC::Contentful has not yet been configured!' if configuration.nil?

      yield configuration
    end
  end

  SERVICES = (WCC::Contentful::Services.instance_methods -
      Object.instance_methods)

  # Include this module to define accessors for every method defined on the
  # {Services} singleton.
  #
  # @example
  #   class MyJob < ApplicationJob
  #     include WCC::Contentful::ServiceAccessors
  #
  #     def perform
  #       Page.find(...)
  #
  #       store.find(...)
  #
  #       client.entries(...)
  #
  #       sync_engine.next
  #     end
  #   end
  # @see Services
  module ServiceAccessors
    SERVICES.each do |m|
      define_method m do
        Services.instance.public_send(m)
      end
    end
  end
end

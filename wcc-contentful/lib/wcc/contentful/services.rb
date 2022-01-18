# frozen_string_literal: true

module WCC::Contentful
  class Services
    class << self
      def instance
        @singleton__instance__ ||= new # rubocop:disable Naming/MemoizedInstanceVariableName
      end
    end

    attr_reader :configuration

    def initialize(configuration = nil)
      @configuration = configuration || WCC::Contentful.configuration
      raise StandardError, 'WCC::Contentful has not yet been configured!' if @configuration.nil?
    end

    # Gets the data-store which executes the queries run against the dynamic
    # models in the WCC::Contentful::Model namespace.
    # This is one of the following based on the configured store method:
    #
    # [:direct] an instance of {WCC::Contentful::Store::CDNAdapter} with a
    #           {WCC::Contentful::SimpleClient::Cdn CDN Client} to access the CDN.
    #
    # [:lazy_sync] an instance of {WCC::Contentful::Middleware::Store::CachingMiddleware}
    #              with the configured ActiveSupport::Cache implementation around a
    #              {WCC::Contentful::Store::CDNAdapter} for when data
    #              cannot be found in the cache.
    #
    # [:eager_sync] an instance of the configured Store type, defined by
    #               {WCC::Contentful::Configuration#sync_store}
    #
    # @api Store
    def store
      @store ||= configuration.store.build(self)
    end

    # An instance of {WCC::Contentful::Store::CDNAdapter} which connects to the
    # Contentful Preview API to return preview content.
    #
    # @api Store
    def preview_store
      @preview_store ||=
        WCC::Contentful::Store::Factory.new(
          configuration,
          :direct,
          :preview
        ).build(self)
    end

    # Gets a {WCC::Contentful::SimpleClient::Cdn CDN Client} which provides
    # methods for getting and paging raw JSON data from the Contentful CDN.
    #
    # @api Client
    def client
      @client ||=
        WCC::Contentful::SimpleClient::Cdn.new(
          **configuration.connection_options,
          access_token: configuration.access_token,
          space: configuration.space,
          default_locale: configuration.default_locale,
          connection: configuration.connection,
          environment: configuration.environment
        )
    end

    # Gets a {WCC::Contentful::SimpleClient::Cdn CDN Client} which provides
    # methods for getting and paging raw JSON data from the Contentful Preview API.
    #
    # @api Client
    def preview_client
      @preview_client ||=
        if configuration.preview_token.present?
          WCC::Contentful::SimpleClient::Preview.new(
            **configuration.connection_options,
            preview_token: configuration.preview_token,
            space: configuration.space,
            default_locale: configuration.default_locale,
            connection: configuration.connection,
            environment: configuration.environment
          )
        end
    end

    # Gets a {WCC::Contentful::SimpleClient::Management Management Client} which provides
    # methods for updating data via the Contentful Management API
    #
    # @api Client
    def management_client
      @management_client ||=
        if configuration.management_token.present?
          WCC::Contentful::SimpleClient::Management.new(
            **configuration.connection_options,
            management_token: configuration.management_token,
            space: configuration.space,
            default_locale: configuration.default_locale,
            connection: configuration.connection,
            environment: configuration.environment
          )
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
        configuration.instrumentation_adapter ||
        ActiveSupport::Notifications
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

# frozen_string_literal: true

require 'singleton'

module WCC::Contentful
  class Services
    include Singleton

    ##
    # Gets the data-store which executes the queries run against the dynamic
    # models in the WCC::Contentful::Model namespace.
    # This is one of the following based on the configured content_delivery method:
    #
    # [:direct] an instance of WCC::Contentful::Store::CDNAdapter with a
    #           {CDN Client}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn] to access the CDN.
    #
    # [:lazy_sync] an instance of WCC::Contentful::Store::LazyCacheStore
    #              with the configured ActiveSupport::Cache implementation and a
    #              {CDN Client}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn] for when data
    #              cannot be found in the cache.
    #
    # [:eager_sync] an instance of the configured Store type, defined by
    #               WCC::Contentful::Configuration.sync_store
    #
    def store
      @store ||=
        ensure_configured do |config|
          WCC::Contentful::Store::Factory.new(
            config,
            self,
            config.content_delivery,
            config.content_delivery_params
          ).build_sync_store
        end
    end

    def preview_store
      @preview_store ||=
        ensure_configured do |config|
          WCC::Contentful::Store::Factory.new(
            config,
            self,
            :direct,
            [{ preview: true }]
          ).build_sync_store
        end
    end

    ##
    # Gets a {CDN Client}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn] which provides
    # methods for getting and paging raw JSON data from the Contentful CDN.
    def client
      @client ||=
        ensure_configured do |config|
          WCC::Contentful::SimpleClient::Cdn.new(
            access_token: config.access_token,
            space: config.space,
            default_locale: config.default_locale,
            adapter: config.http_adapter,
            environment: config.environment
          )
        end
    end

    ##
    # Gets a {CDN Client}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn] which provides
    # methods for getting and paging raw JSON data from the Contentful Preview API.
    def preview_client
      @preview_client ||=
        ensure_configured do |config|
          if config.preview_token.present?
            WCC::Contentful::SimpleClient::Preview.new(
              preview_token: config.preview_token,
              space: config.space,
              default_locale: config.default_locale,
              adapter: config.http_adapter
            )
          end
        end
    end

    def management_client
      @management_client ||=
        ensure_configured do |config|
          if config.management_token.present?
            WCC::Contentful::SimpleClient::Management.new(
              management_token: config.management_token,
              space: config.space,
              default_locale: config.default_locale,
              adapter: config.http_adapter,
              environment: config.environment
            )
          end
        end
    end

    private

    def ensure_configured
      if WCC::Contentful.configuration.nil?
        raise StandardError, 'WCC::Contentful has not yet been configured!'
      end
      yield WCC::Contentful.configuration
    end
  end

  module ServiceAccessors
    SERVICES = (WCC::Contentful::Services.instance_methods -
      Object.instance_methods -
      Singleton.instance_methods)

    SERVICES.each do |m|
      define_method m do
        Services.instance.public_send(m)
      end
    end
  end
end

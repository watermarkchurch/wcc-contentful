# frozen_string_literal: true

require_relative 'store/base'
require_relative 'store/memory_store'
require_relative 'store/cdn_adapter'
require_relative 'store/lazy_cache_store'

# The "Store" is the middle layer in the WCC::Contentful gem.  It exposes an API
# that implements the configured content delivery strategy.
#
# The different content delivery strategies require different store implementations.
#
# direct:: Uses the WCC::Contentful::Store::CDNAdapter to wrap the Contentful CDN,
#          providing an API consistent with the other stores.  Any query made to
#          the CDNAdapter will be immediately passed through to the API.
#          The CDNAdapter does not implement #index because it does not care about
#          updates coming from the Sync API.
#
# lazy_sync:: Uses the Contentful CDN in combination with an ActiveSupport::Cache
#             implementation in order to respond with the cached data where possible,
#             saving your CDN quota.  The cache is kept up-to-date via the Sync API
#             and the WCC::Contentful::DelayedSyncJob.  It is correct, but not complete.
#
# eager_sync:: Uses one of the full store implementations to store the entirety
#              of the Contentful space locally.  All queries are run against this
#              local copy, which is kept up to date via the Sync API and the
#              WCC::Contentful::DelayedSyncJob.  The local store is correct and complete.
#
# The currently configured store is available on WCC::Contentful::Services.instance.store
module WCC::Contentful::Store
  SYNC_STORES = {
    memory: ->(_config) { WCC::Contentful::Store::MemoryStore.new },
    postgres: ->(config, *options) {
      require_relative 'store/postgres_store'
      WCC::Contentful::Store::PostgresStore.new(config, *options)
    }
  }.freeze

  CDN_METHODS = %i[
    eager_sync
    lazy_sync
    direct
    custom
  ].freeze

  Factory =
    Struct.new(:config, :services, :cdn_method, :content_delivery_params) do
      def build_sync_store
        unless respond_to?("build_#{cdn_method}")
          raise ArgumentError, "Don't know how to build content delivery method #{cdn_method}"
        end

        public_send("build_#{cdn_method}", config, *content_delivery_params)
      end

      def validate!
        unless CDN_METHODS.include?(cdn_method)
          raise ArgumentError, "Please use one of #{CDN_METHODS} instead of #{cdn_method}"
        end

        return unless respond_to?("validate_#{cdn_method}")
        public_send("validate_#{cdn_method}", config, *content_delivery_params)
      end

      def build_eager_sync(config, store = nil, *options)
        store = SYNC_STORES[store].call(config, *options) if store.is_a?(Symbol)
        store || MemoryStore.new
      end

      def build_lazy_sync(_config, *options)
        WCC::Contentful::Store::LazyCacheStore.new(
          services.client,
          cache: ActiveSupport::Cache.lookup_store(*options)
        )
      end

      def build_direct(_config, *options)
        if options.find { |array| array[:preview] == true }
          CDNAdapter.new(services.preview_client)
        else
          CDNAdapter.new(services.client)
        end
      end

      def build_custom(config, *options)
        store = config.store
        return store unless store&.respond_to?(:new)
        store.new(config, options)
      end

      def validate_eager_sync(_config, store = nil, *_options)
        return unless store.is_a?(Symbol)

        return if SYNC_STORES.key?(store)
        raise ArgumentError, "Please use one of #{SYNC_STORES.keys}"
      end
    end
end

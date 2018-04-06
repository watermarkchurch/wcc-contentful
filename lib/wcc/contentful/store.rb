
# frozen_string_literal: true

require_relative 'store/base'
require_relative 'store/memory_store'
require_relative 'store/lazy_cache_store'
require_relative 'store/cdn_adapter'

# required dynamically if they select the 'postgres' store option
# require_relative 'store/postgres_store'

module WCC::Contentful::Store
  SYNC_STORES = {
    memory: ->(_config) { WCC::Contentful::Store::MemoryStore.new },
    postgres: ->(_config) {
      require_relative 'store/postgres_store'
      WCC::Contentful::Store::PostgresStore.new(ENV['POSTGRES_CONNECTION'])
    }
  }.freeze

  CDN_METHODS = %i[
    eager_sync
    lazy_sync
    direct
  ].freeze

  Factory =
    Struct.new(:config, :cdn_method, :content_delivery_params, :use_preview_boolean) do
      def build_sync_store
        unless respond_to?("build_#{cdn_method}")
          raise ArgumentError, "Don't know how to build content delivery method #{cdn_method}"
        end

        if cdn_method == :direct
          public_send("build_#{cdn_method}", config, *content_delivery_params, use_preview_boolean)
        else
          public_send("build_#{cdn_method}", config, *content_delivery_params)
        end
      end

      def validate!
        unless CDN_METHODS.include?(cdn_method)
          raise ArgumentError, "Please use one of #{CDN_METHODS} for 'content_delivery'"
        end

        return unless respond_to?("validate_#{cdn_method}")
        public_send("validate_#{cdn_method}", config, *content_delivery_params)
      end

      def build_eager_sync(config, store = nil, *_options)
        puts "store: #{store}"
        store = SYNC_STORES[store].call(config) if store.is_a?(Symbol)
        store || MemoryStore.new
      end

      def build_lazy_sync(config, *options)
        WCC::Contentful::Store::LazyCacheStore.new(
          config.client,
          cache: ActiveSupport::Cache.lookup_store(*options)
        )
      end

      def build_direct(config, *_options, use_preview_boolean)
        if use_preview_boolean
          CDNAdapter.new(config.preview_client)
        else
          CDNAdapter.new(config.client)
        end
      end

      def validate_eager_sync(_config, store = nil, *_options)
        return unless store.is_a?(Symbol)

        return if SYNC_STORES.keys.include?(store)
        raise ArgumentError, "Please use one of #{SYNC_STORES.keys}"
      end
    end
end

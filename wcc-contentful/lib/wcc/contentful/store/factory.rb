# frozen_string_literal: true

require_relative 'base'
require_relative 'memory_store'
require_relative 'cdn_adapter'
require_relative '../middleware/store'
require_relative '../middleware/store/caching_middleware'

module WCC::Contentful::Store
  class Factory
    attr_reader :wcc_contentful_config, :cdn_method, :content_delivery_params, :config

    def initialize(wcc_contentful_config, cdn_method = nil, content_delivery_params = nil)
      @wcc_contentful_config = wcc_contentful_config
      @cdn_method = cdn_method
      @content_delivery_params = content_delivery_params || []
      @config = DSL.new

      return unless @cdn_method

      # Infer whether they passed in a store implementation object or class
      return unless class_implements_store_interface?(@cdn_method) ||
        object_implements_store_interface?(@cdn_method)

      @content_delivery_params.unshift(@cdn_method)
      @cdn_method = :custom
    end

    def configure(&block)
      @config.instance_exec(&block)
    end

    def build_sync_store(services = WCC::Contentful::Services.instance)
      unless respond_to?("build_#{cdn_method}")
        raise ArgumentError, "Don't know how to build content delivery method '#{cdn_method}'"
      end

      built = public_send("build_#{cdn_method}", services)
      options = {
        config: config,
        services: services
      }
      config.middleware.reverse
        .reduce(built) do |memo, (middleware, params, configure_proc)|
          middleware = middleware.call(memo, *params, **options)
          middleware.instance_exec(&configure_proc) if configure_proc
          middleware || memo
        end
    end

    def validate!
      unless cdn_method.nil? || CDN_METHODS.include?(cdn_method)
        raise ArgumentError, "Please use one of #{CDN_METHODS} instead of #{cdn_method}"
      end

      config.middleware.each do |m|
        next if m[0].respond_to?(:call)

        raise ArgumentError, "The middleware '#{m[0]&.try(:name) || m[0]}' cannot be applied!  " \
          'It must respond to :call'
      end

      return unless respond_to?("validate_#{cdn_method}")

      public_send("validate_#{cdn_method}")
    end

    def build_eager_sync(_services)
      store = content_delivery_params[0] || :memory
      store = SYNC_STORES[store].call(config, *content_delivery_params) if store.is_a?(Symbol)
      store || MemoryStore.new
    end

    def build_lazy_sync(services)
      WCC::Contentful::Store::CachingMiddleware.call(
        build_direct(services),
        ActiveSupport::Cache.lookup_store(*content_delivery_params)
      )
    end

    def build_direct(services)
      if content_delivery_params.include?(:preview)
        CDNAdapter.new(services.preview_client)
      else
        CDNAdapter.new(services.client)
      end
    end

    def build_custom(services)
      store = config.store || content_delivery_params[0]
      return store if object_implements_store_interface?(store)

      instance = store.new(config, *content_delivery_params - [store])
      (WCC::Contentful::SERVICES - %i[store preview_store]).each do |s|
        next unless instance.respond_to?("#{s}=")

        instance.public_send("#{s}=",
          services.public_send(s))
      end
      instance
    end

    def validate_eager_sync
      return unless config.store.is_a?(Symbol)

      return if SYNC_STORES.key?(store)

      raise ArgumentError, "Please use one of #{SYNC_STORES.keys}"
    end

    def validate_custom
      store = config.store || content_delivery_params[0]
      raise ArgumentError, 'No custom store provided for :custom content delivery' unless store

      return true if class_implements_store_interface?(store) ||
        object_implements_store_interface?(store)

      methods = [*store.try(:instance_methods), *store.try(:methods)]
      INTERFACE_METHODS.each do |method|
        next if methods.include?(method)

        raise ArgumentError, "Custom store '#{store}' must respond to the #{method} method"
      end
    end

    INTERFACE_METHODS = WCC::Contentful::Store::Interface.instance_methods - Module.instance_methods

    def class_implements_store_interface?(klass)
      (INTERFACE_METHODS - (klass.try(:instance_methods) || [])).empty?
    end

    def object_implements_store_interface?(object)
      (INTERFACE_METHODS - (object.try(:methods) || [])).empty?
    end

    class DSL
      attr_reader :store, :middleware
      attr_writer :store
      def initialize
        @middleware = []
      end

      # Adds a middleware to the chain.  Use a block here to configure the middleware
      # after it has been created.
      def use(middleware, *middleware_params, &block)
        configure_proc = block_given? ? Proc.new(&block) : nil
        self.middleware << [middleware, middleware_params, configure_proc]
      end
    end
  end
end

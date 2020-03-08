# frozen_string_literal: true

require_relative 'base'
require_relative 'memory_store'
require_relative 'cdn_adapter'
require_relative '../middleware/store'
require_relative '../middleware/store/caching_middleware'

module WCC::Contentful::Store
  class Factory
    attr_reader :cdn_method, :content_delivery_params

    # An array of tuples that set up and configure a Store middleware.
    def middleware
      @middleware ||= self.class.default_middleware
    end

    def initialize(cdn_method = :direct, content_delivery_params = nil)
      @cdn_method = cdn_method || :custom
      @content_delivery_params = [*content_delivery_params] || []

      # Infer whether they passed in a store implementation object or class
      return unless class_implements_store_interface?(@cdn_method) ||
        object_implements_store_interface?(@cdn_method)

      @content_delivery_params.unshift(@cdn_method)
      @cdn_method = :custom
    end

    # Adds a middleware to the chain.  Use a block here to configure the middleware
    # after it has been created.
    def use(middleware, *middleware_params, &block)
      configure_proc = block_given? ? Proc.new(&block) : nil
      self.middleware << [middleware, middleware_params, configure_proc]
    end

    def build(config = WCC::Contentful.configuration, services = WCC::Contentful::Services.instance)
      unless respond_to?("build_#{cdn_method}")
        raise ArgumentError, "Don't know how to build content delivery method '#{cdn_method}'"
      end

      built = public_send("build_#{cdn_method}", config, services)
      options = {
        config: config,
        services: services
      }
      middleware.reverse
        .reduce(built) do |memo, middleware_config|
          # May have added a middleware with `middleware << MyMiddleware.new`
          middleware_config = [middleware_config] unless middleware_config.is_a? Array

          middleware, params, configure_proc = middleware_config
          middleware = middleware.call(memo, *params, **options)
          middleware.instance_exec(&configure_proc) if configure_proc
          middleware || memo
        end
    end

    def validate!
      unless cdn_method.nil? || CDN_METHODS.include?(cdn_method)
        raise ArgumentError, "Please use one of #{CDN_METHODS} instead of #{cdn_method}"
      end

      middleware.each do |m|
        next if m[0].respond_to?(:call)

        raise ArgumentError, "The middleware '#{m[0]&.try(:name) || m[0]}' cannot be applied!  " \
          'It must respond to :call'
      end

      return unless respond_to?("validate_#{cdn_method}")

      public_send("validate_#{cdn_method}")
    end

    def build_eager_sync(config, _services)
      store = content_delivery_params[0] || :memory
      store = SYNC_STORES[store].call(config, *content_delivery_params) if store.is_a?(Symbol)
      store || MemoryStore.new
    end

    def build_lazy_sync(config, services)
      WCC::Contentful::Middleware::Store::CachingMiddleware.call(
        build_direct(config, services),
        ActiveSupport::Cache.lookup_store(*content_delivery_params)
      )
    end

    def build_direct(_config, services)
      if content_delivery_params.include?(:preview)
        CDNAdapter.new(services.preview_client)
      else
        CDNAdapter.new(services.client)
      end
    end

    def build_custom(config, services)
      store = content_delivery_params[0]
      instance =
        if object_implements_store_interface?(store)
          store
        else
          store.new(config, *content_delivery_params - [store])
        end

      (WCC::Contentful::SERVICES - %i[store preview_store]).each do |s|
        next unless instance.respond_to?("#{s}=")

        instance.public_send("#{s}=",
          services.public_send(s))
      end
      instance
    end

    def validate_eager_sync
      store = content_delivery_params[0]
      return unless store.is_a?(Symbol)

      return if SYNC_STORES.key?(store)

      raise ArgumentError, "Please use one of #{SYNC_STORES.keys}"
    end

    def validate_custom
      store = content_delivery_params[0]
      raise ArgumentError, 'No custom store provided for :custom content delivery' unless store

      return true if class_implements_store_interface?(store) ||
        object_implements_store_interface?(store)

      methods = [*store.try(:instance_methods), *store.try(:methods)]
      INTERFACE_METHODS.each do |method|
        next if methods.include?(method)

        raise ArgumentError, "Custom store '#{store}' must respond to the #{method} method"
      end
    end

    def class_implements_store_interface?(klass)
      (WCC::Contentful::Store::Interface::INTERFACE_METHODS -
          (klass.try(:instance_methods) || [])).empty?
    end

    def object_implements_store_interface?(object)
      (WCC::Contentful::Store::Interface::INTERFACE_METHODS -
          (object.try(:methods) || [])).empty?
    end

    class << self
      # The middleware that by default lives at the top of the middleware stack.
      def default_middleware
        [
          [WCC::Contentful::Store::InstrumentationMiddleware]
        ]
      end
    end
  end
end

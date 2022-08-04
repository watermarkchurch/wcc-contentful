# frozen_string_literal: true

require_relative 'base'
require_relative 'memory_store'
require_relative 'cdn_adapter'
require_relative '../middleware/store'
require_relative '../middleware/store/caching_middleware'
require_relative '../middleware/store/locale_middleware'

module WCC::Contentful::Store
  # This factory presents a DSL for configuring the store stack.  The store stack
  # sits in between the Model layer and the datastore, which can be Contentful
  # or something else like Postgres.
  #
  # A set of "presets" are available to get pre-configured stacks based on what
  # we've found most useful.
  class Factory
    attr_reader :preset, :options, :config

    # Set the base store instance.
    attr_accessor :store

    # An array of tuples that set up and configure a Store middleware.
    def middleware
      @middleware ||= self.class.default_middleware.dup
    end

    def initialize(config = WCC::Contentful.configuration, preset = :direct, options = nil)
      @config = config
      @preset = preset || :custom
      @options = [*options] || []

      # Infer whether they passed in a store implementation object or class
      if class_implements_store_interface?(@preset) ||
          object_implements_store_interface?(@preset)
        @options.unshift(@preset)
        @preset = :custom
      end

      configure_preset(@preset)
    end

    # Adds a middleware to the chain.  Use a block here to configure the middleware
    # after it has been created.
    def use(middleware, *middleware_params, &block)
      configure_proc = block_given? ? Proc.new(&block) : nil
      self.middleware << [middleware, middleware_params, configure_proc]
    end

    # Replaces a middleware in the chain.  The middleware to replace is selected
    # by matching the class.
    def replace(middleware, *middleware_params, &block)
      idx = self.middleware.find_index { |m| m[0] == middleware }
      raise ArgumentError, "Middleware #{middleware} not present" if idx.nil?

      configure_proc = block_given? ? Proc.new(&block) : nil
      self.middleware[idx] = [middleware, middleware_params, configure_proc]
    end

    # Removes a middleware from the chain, finding it by matching the class
    # constant.
    def unuse(middleware)
      idx = self.middleware.find_index { |m| m[0] == middleware }
      return if idx.nil?

      self.middleware.delete_at idx
    end

    def build(services = WCC::Contentful::Services.instance)
      store_instance = build_store(services)
      options = {
        config: config,
        services: services
      }
      middleware.reverse
        .reduce(store_instance) do |memo, middleware_config|
          # May have added a middleware with `middleware << MyMiddleware.new`
          middleware_config = [middleware_config] unless middleware_config.is_a? Array

          middleware, params, configure_proc = middleware_config
          middleware_options = options.merge((params || []).extract_options!)
          middleware = middleware.call(memo, *params, **middleware_options)
          services.inject_into(middleware, except: %i[store preview_store])
          middleware&.instance_exec(&configure_proc) if configure_proc
          middleware || memo
        end
    end

    def validate!
      unless preset.nil? || PRESETS.include?(preset)
        raise ArgumentError, "Please use one of #{PRESETS} instead of #{preset}"
      end

      middleware.each do |m|
        next if m[0].respond_to?(:call)

        raise ArgumentError, "The middleware '#{m[0]&.try(:name) || m[0]}' cannot be applied!  " \
                             'It must respond to :call'
      end

      validate_store!(store)
    end

    # Sets the "eager sync" preset using one of the preregistered stores like :postgres
    def preset_eager_sync
      store = options.shift || :memory
      store = SYNC_STORES[store]&.call(config, *options) if store.is_a?(Symbol)
      self.store = store

      # Eager sync stores don't respect "locale=" param like CDN does
      use(WCC::Contentful::Middleware::Store::LocaleMiddleware)
    end

    # Configures a "lazy sync" preset which caches direct lookups but hits Contentful
    # for any missing information.  The cache is kept up to date by the sync engine.
    def preset_lazy_sync
      preset_direct
      use(WCC::Contentful::Middleware::Store::CachingMiddleware,
        ActiveSupport::Cache.lookup_store(*options))
    end

    # Configures the default "direct" preset which passes everything through to
    # Contentful CDN
    def preset_direct
      self.store = CDNAdapter.new(preview: options.include?(:preview))
    end

    def preset_custom
      self.store = options.shift

      # Custom stores might not respect "locale=" param like CDN does
      use(WCC::Contentful::Middleware::Store::LocaleMiddleware)
    end

    private

    def validate_store!(store)
      raise ArgumentError, 'No store provided' unless store

      return true if class_implements_store_interface?(store) ||
        object_implements_store_interface?(store)

      methods = [*store.try(:instance_methods), *store.try(:methods)]
      WCC::Contentful::Store::Interface::INTERFACE_METHODS.each do |method|
        next if methods.include?(method)

        raise ArgumentError, "Custom store '#{store}' must respond to the #{method} method"
      end
    end

    def configure_preset(preset)
      unless respond_to?("preset_#{preset}")
        raise ArgumentError, "Don't know how to build content delivery method '#{preset}'"
      end

      public_send("preset_#{preset}")
    end

    def build_store(services)
      store_class = store
      store =
        if object_implements_store_interface?(store_class)
          store_class
        else
          store_class.new(config, *options - [store_class])
        end

      # Inject services into the custom store class
      services.inject_into(store, except: %i[store preview_store])

      store
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
        ].freeze
      end
    end
  end
end

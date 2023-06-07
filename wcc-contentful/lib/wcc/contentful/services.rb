# frozen_string_literal: true

module WCC::Contentful
  class Services
    class << self
      def instance
        @singleton__instance__ ||= # rubocop:disable Naming/MemoizedInstanceVariableName
          (new(WCC::Contentful.configuration) if WCC::Contentful.configuration)
      end
    end

    attr_reader :configuration

    def initialize(configuration, model_namespace: nil)
      raise ArgumentError, 'Not yet configured!' unless configuration

      @configuration = configuration
      @model_namespace = model_namespace
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
          environment: configuration.environment,
          instrumentation: instrumentation
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
            environment: configuration.environment,
            instrumentation: instrumentation
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
            environment: configuration.environment,
            instrumentation: instrumentation
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

    # Returns a callable object which can be used to render a rich text document.
    # This object will have all the connected services injected into it.
    # The implementation class is configured by {WCC::Contentful::Configuration#rich_text_renderer}.
    # In a rails context the default implementation is {WCC::Contentful::ActionViewRichTextRenderer}.
    def rich_text_renderer
      @rich_text_renderer ||=
        if implementation_class = configuration&.rich_text_renderer
          store = self.store
          config = configuration
          model_namespace = @model_namespace || WCC::Contentful::Model

          # Wrap the implementation in a subclass that injects the services
          Class.new(implementation_class) do
            define_method :initialize do |document, *args, **kwargs|
              # Implementation might choose to override these, so call super last
              @store = store
              @config = config
              @model_namespace = model_namespace
              super(document, *args, **kwargs)
            end
          end
        else
          # Create a renderer that renders a more helpful error message, but delay the error message until #to_html
          # is actually invoked in case the user never actually uses the renderer.
          Class.new(WCC::Contentful::RichTextRenderer) do
            def call
              raise WCC::Contentful::RichTextRenderer::AbstractRendererError,
                'No rich text renderer implementation has been configured.  ' \
                'Please install a supported implementation such as ActionView, ' \
                'or set WCC::Contentful.configuration.rich_text_renderer to a custom implementation.'
            end
          end
        end
    end

    # Gets the configured instrumentation adapter, defaulting to ActiveSupport::Notifications
    def instrumentation
      @instrumentation ||=
        configuration.instrumentation_adapter ||
        ActiveSupport::Notifications
    end
    # Allow it to be injected into a store
    alias_method :_instrumentation, :instrumentation

    # Gets the configured logger, defaulting to Rails.logger in a rails context,
    # or logging to STDERR in a non-rails context.
    def logger
      @logger ||=
        configuration.logger ||
        (Rails.logger if defined?(Rails)) ||
        Logger.new($stderr)
    end

    ##
    # This method enables simple dependency injection -
    # If the target has a setter matching the name of one of the services,
    # set that setter with the value of the service.
    def inject_into(target, except: [])
      (WCC::Contentful::SERVICES - except).each do |s|
        next unless target.respond_to?("#{s}=")

        target.public_send("#{s}=",
          public_send(s))
      end
    end
  end

  SERVICES =
    WCC::Contentful::Services.instance_methods(false)
      .select { |m| WCC::Contentful::Services.instance_method(m).arity == 0 }

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

# frozen_string_literal: true

class WCC::Contentful::Configuration
  ATTRIBUTES = %i[
    access_token
    app_url
    management_token
    space
    environment
    default_locale
    content_delivery
    preview_token
    http_adapter
    sync_cache_store
    webhook_username
    webhook_password
  ].freeze
  attr_accessor(*ATTRIBUTES)

  ##
  # Defines the method by which content is downloaded from the Contentful CDN.
  #
  # [:direct] `config.content_delivery = :direct`
  #           with the `:direct` method, all queries result in web requests to
  #           'https://cdn.contentful.com' via the
  #           {SimpleClient}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn]
  #
  # [:eager_sync] `config.content_delivery = :eager_sync, [sync_store], [options]`
  #               with the `:eager_sync` method, the entire content of the Contentful
  #               space is downloaded locally and stored in the
  #               {Sync Store}[rdoc-ref:WCC::Contentful.store].  The application is responsible
  #               to periodically call `WCC::Contentful.sync!` to keep the store updated.
  #               Alternatively, the provided {Engine}[WCC::Contentful::Engine]
  #               can be mounted to receive a webhook from the Contentful space
  #               on publish events:
  #                 mount WCC::Contentful::Engine, at: '/wcc/contentful'
  #
  # [:lazy_sync] `config.content_delivery = :lazy_sync, [cache]`
  #              The `:lazy_sync` method is a hybrid between the other two methods.
  #              Frequently accessed data is stored in an ActiveSupport::Cache implementation
  #              and is kept up-to-date via the Sync API.  Any data that is not present
  #              in the cache is fetched from the CDN like in the `:direct` method.
  #              The application is still responsible to periodically call `sync!`
  #              or to mount the provided Engine.
  #
  def content_delivery=(params)
    cd, *cd_params = params
    unless cd.is_a? Symbol
      raise ArgumentError, 'content_delivery must be a symbol, use store= to '\
        'directly set contentful CDN access adapter'
    end

    WCC::Contentful::Store::Factory.new(
      self,
      cd,
      cd_params
    ).validate!

    @content_delivery = cd
    @content_delivery_params = cd_params
  end

  ##
  # Initializes the configured Sync Store.
  def store(preview: false)
    if preview
      @preview_store ||= WCC::Contentful::Store::Factory.new(
        self,
        :direct,
        [{ preview: preview }]
      ).build_sync_store
    else
      @store ||= WCC::Contentful::Store::Factory.new(
        self,
        @content_delivery,
        @content_delivery_params
      ).build_sync_store
    end
  end

  ##
  # Directly sets the adapter layer for communicating with Contentful
  def store=(value)
    @content_delivery = :custom
    @store = value
  end

  # Sets the adapter which is used to make HTTP requests.
  # If left unset, the gem attempts to load either 'http' or 'typhoeus'.
  # You can pass your own adapter which responds to 'call', or even a lambda
  # that accepts the following parameters:
  #  ->(url, query, headers = {}, proxy = {}) { ... }
  attr_writer :http_adapter

  def initialize
    @access_token = ''
    @app_url = ENV['APP_URL']
    @management_token = ''
    @preview_token = ''
    @space = ''
    @default_locale = nil
    @content_delivery = :direct
  end

  ##
  # Gets a {CDN Client}[rdoc-ref:WCC::Contentful::SimpleClient::Cdn] which provides
  # methods for getting and paging raw JSON data from the Contentful CDN.
  attr_reader :client
  attr_reader :management_client
  attr_reader :preview_client

  ##
  # Called by WCC::Contentful.init! to configure the
  # Contentful clients.  This method can be called independently of `init!` if
  # the application would prefer not to generate all the models.
  #
  # If the {contentful.rb}[https://github.com/contentful/contentful.rb] gem is
  # loaded, it is extended to make use of the `http_adapter` lambda.
  def configure_contentful
    @client = nil
    @management_client = nil
    @preview_client = nil

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
      default_locale: default_locale,
      adapter: http_adapter,
      environment: environment
    )

    if preview_token.present?
      @preview_client = WCC::Contentful::SimpleClient::Preview.new(
        preview_token: preview_token,
        space: space,
        default_locale: default_locale,
        adapter: http_adapter
      )
    end

    return unless management_token.present?
    @management_client = WCC::Contentful::SimpleClient::Management.new(
      management_token: management_token,
      space: space,
      default_locale: default_locale,
      adapter: http_adapter,
      environment: environment
    )
  end

  def validate!
    raise ArgumentError, 'Please provide "space"' unless space.present?
    raise ArgumentError, 'Please provide "access_token"' unless access_token.present?

    return if environment.nil? || %i[direct custom].include?(content_delivery)
    raise ArgumentError, 'The Contentful Sync API currently does not work with environments.  ' \
      'You can use the ":direct" content_delivery method, or provide a custom store implementation.'
  end
end

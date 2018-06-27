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
    webhook_jobs
  ].freeze
  attr_accessor(*ATTRIBUTES)

  # Defines the method by which content is downloaded from the Contentful CDN.
  #
  # [:direct] `config.content_delivery = :direct`
  #           with the `:direct` method, all queries result in web requests to
  #           'https://cdn.contentful.com' via the
  #           {WCC::Contentful::SimpleClient::Cdn SimpleClient}
  #
  # [:eager_sync] `config.content_delivery = :eager_sync, [sync_store], [options]`
  #               with the `:eager_sync` method, the entire content of the Contentful
  #               space is downloaded locally and stored in the
  #               {WCC::Contentful::Services#store configured store}.  The application is
  #               responsible to periodically call `WCC::Contentful.sync!` to keep the store
  #               updated. Alternatively, the provided {WCC::Contentful::Engine Engine}
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
      nil,
      cd,
      cd_params
    ).validate!

    @content_delivery = cd
    @content_delivery_params = cd_params
  end

  attr_reader :content_delivery_params

  # Directly sets the adapter layer for communicating with Contentful
  def store=(value)
    @content_delivery = :custom
    store, *cd_params = value
    @store = store
    @content_delivery_params = cd_params
  end

  attr_reader :store

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
    @webhook_jobs = []
  end

  def validate!
    raise ArgumentError, 'Please provide "space"' unless space.present?
    raise ArgumentError, 'Please provide "access_token"' unless access_token.present?

    webhook_jobs&.each do |job|
      next if job.respond_to?(:call) || job.respond_to?(:perform_later)
      raise ArgumentError, "The job '#{job}' must be an instance of ActiveJob::Base or respond to :call"
    end

    return unless environment.present? && %i[eager_sync lazy_sync].include?(content_delivery)
    raise ArgumentError, 'The Contentful Sync API currently does not work with environments.  ' \
      'You can use the ":direct" content_delivery method, or provide a custom store implementation.'
  end
end

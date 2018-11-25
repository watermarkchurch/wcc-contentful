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

  # Returns true if the currently configured environment is pointing at `master`.
  def master?
    !environment.present?
  end

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

  # Indicates whether to update the contentful-schema.json file for building models.
  # The schema can also be updated with `rake wcc_contentful:download_schema`
  # Valid values are:
  #
  # never:: wcc-contentful not update the schema even if a management token is available.
  #         If your schema file is out of date this could cause null-reference errors or
  #         not found errors at runtime.  If your schema file does not exist or is invalid,
  #         WCC::Contentful.init! will raise a WCC::Contentful::InitializitionError
  #
  # if_possible:: wcc-contentful will attempt to reach out to the management API for
  #               content types, and will fall back to the schema file if the API
  #               cannot be reached.  This is the default.
  #
  # always:: wcc-contentful will check either the management API or the CDN for the
  #          most up-to-date content types and will raise a WCC::Contentful::InitializationError
  #          if the API cannot be reached.
  def update_schema_file=(sym)
    valid_syms = %i[never if_possible always]
    unless valid_syms.include?(sym)
      raise ArgumentError, "update_schema_file must be one of #{valid_syms}"
    end

    @update_schema_file = sym
  end
  attr_reader :update_schema_file

  # The file to store the Contentful schema in.  You should check this into source
  # control, similar to `db/schema.rb`.  This filename is relative to the rails root.
  # Defaults to 'db/contentful-schema.json
  attr_writer :schema_file

  def schema_file
    Rails.root.join(@schema_file)
  end

  def initialize
    @access_token = ''
    @app_url = ENV['APP_URL']
    @management_token = ''
    @preview_token = ''
    @space = ''
    @default_locale = nil
    @content_delivery = :direct
    @update_schema_file = :if_possible
    @schema_file = 'db/contentful-schema.json'
    @webhook_jobs = []
  end

  def validate!
    raise ArgumentError, 'Please provide "space"' unless space.present?
    raise ArgumentError, 'Please provide "access_token"' unless access_token.present?

    webhook_jobs&.each do |job|
      next if job.respond_to?(:call) || job.respond_to?(:perform_later)

      raise ArgumentError, "The job '#{job}' must be an instance of ActiveJob::Base or respond to :call"
    end
  end
end

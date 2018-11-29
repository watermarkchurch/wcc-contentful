# frozen_string_literal: true

# This object contains all the configuration options for the `wcc-contentful` gem.
class WCC::Contentful::Configuration
  ATTRIBUTES = %i[
    space
    access_token
    app_url
    management_token
    environment
    default_locale
    preview_token
    webhook_username
    webhook_password
    webhook_jobs
    content_delivery
    content_delivery_params
    store
    http_adapter
    update_schema_file
    schema_file
  ].freeze

  # (required) Sets the Contentful Space ID.
  attr_accessor :space
  # (required) Sets the Content Delivery API access token.
  attr_accessor :access_token

  # Sets the app's root URL for a Rails app.  Used by the WCC::Contentful::Engine
  # to automatically set up webhooks to point at the WCC::Contentful::WebhookController
  attr_accessor :app_url
  # Sets the Content Management Token used to communicate with the Management API.
  # This is required for automatically setting up webhooks, and to create the
  # WCC::Contentful::Services#management_client.
  attr_accessor :management_token
  # Sets the Environment ID.  Leave blank to use master.
  attr_accessor :environment
  # Sets the default locale.  Defaults to 'en-US'.
  attr_accessor :default_locale
  # Sets the Content Preview API access token.  Only required if you use the
  # preview flag.
  attr_accessor :preview_token
  # Sets an optional basic auth username that will be validated by the webhook controller.
  # You must ensure the configured webhook sets the "HTTP Basic Auth username"
  attr_accessor :webhook_username
  # Sets an optional basic auth password that will be validated by the webhook controller.
  # You must ensure the configured webhook sets the "HTTP Basic Auth password"
  attr_accessor :webhook_password
  # An array of jobs that are run whenever a webhook is received by the webhook controller.
  # The job can be an ActiveJob class which responds to `:perform_later`, or a lambda or
  # other object that responds to `:call`.
  # Example:
  #  config.webhook_jobs << MyJobClass
  #  config.webhook_jobs << ->(event) { ... }
  #
  # See the source code for WCC::Contentful::SyncEngine::Job for an example of how
  # to implement a webhook job.
  attr_accessor :webhook_jobs

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
  #               responsible to periodically call the WCC::Contentful::SyncEngine#next to
  #               keep the store updated. Alternatively, the provided {WCC::Contentful::Engine Engine}
  #               can be mounted to automatically call WCC::Contentful::SyncEngine#next on
  #               webhook events.
  #               on publish events:
  #                 mount WCC::Contentful::Engine, at: '/'
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

  # Gets the configured content_delivery symbol
  attr_reader :content_delivery
  # Gets the parameters passed in the content_delivery configuration
  attr_reader :content_delivery_params

  # Directly sets the adapter layer for communicating with Contentful.
  # This overrides the content_delivery setting to `:custom`.
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
  attr_accessor :http_adapter

  # Indicates whether to update the contentful-schema.json file for building models.
  # The schema can also be updated with `rake wcc_contentful:download_schema`
  # Valid values are:
  #
  # [:never] wcc-contentful will not update the schema even if a management token is available.
  #          If your schema file is out of date this could cause null-reference errors or
  #          not found errors at runtime.  If your schema file does not exist or is invalid,
  #          WCC::Contentful.init! will raise a WCC::Contentful::InitializitionError
  #
  # [:if_possible] wcc-contentful will attempt to reach out to the management API for
  #                content types, and will fall back to the schema file if the API
  #                cannot be reached.  This is the default.
  #
  # [:always] wcc-contentful will check either the management API or the CDN for the
  #           most up-to-date content types and will raise a
  #           WCC::Contentful::InitializationError if the API cannot be reached.
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

  # Validates the configuration, raising ArgumentError if anything is wrong.  This
  # is called by WCC::Contentful.init!
  def validate!
    raise ArgumentError, 'Please provide "space"' unless space.present?
    raise ArgumentError, 'Please provide "access_token"' unless access_token.present?

    if update_schema_file == :always && management_token.blank?
      raise ArgumentError, 'A management_token is required in order to update the schema file.'
    end

    webhook_jobs&.each do |job|
      next if job.respond_to?(:call) || job.respond_to?(:perform_later)

      raise ArgumentError, "The job '#{job}' must be an instance of ActiveJob::Base or respond to :call"
    end
  end

  def freeze
    FrozenConfiguration.new(self)
  end

  class FrozenConfiguration
    attr_reader(*ATTRIBUTES)

    def initialize(configuration)
      ATTRIBUTES.each do |att|
        val = configuration.public_send(att)
        val.freeze if val.respond_to?(:freeze)
        instance_variable_set("@#{att}", val)
      end
    end

    # Returns true if the currently configured environment is pointing at `master`.
    def master?
      !environment.present?
    end
  end
end

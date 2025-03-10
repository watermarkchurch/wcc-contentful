# frozen_string_literal: true

require 'wcc/contentful/version'

require 'active_support'
require 'active_support/all'

require 'wcc/contentful/active_record_shim'
require 'wcc/contentful/configuration'
require 'wcc/contentful/downloads_schema'
require 'wcc/contentful/exceptions'
require 'wcc/contentful/helpers'
require 'wcc/contentful/entry_locale_transformer'
require 'wcc/contentful/link_visitor'
require 'wcc/contentful/services'
require 'wcc/contentful/simple_client'
require 'wcc/contentful/store'
require 'wcc/contentful/content_type_indexer'
require 'wcc/contentful/model'
require 'wcc/contentful/model_methods'
require 'wcc/contentful/model_singleton_methods'
require 'wcc/contentful/model_builder'
require 'wcc/contentful/rich_text'
require 'wcc/contentful/rich_text_renderer'
require 'wcc/contentful/rich_text_renderer_factory'
require 'wcc/contentful/sync_engine'
require 'wcc/contentful/webhook_enable_job'
require 'wcc/contentful/events'
require 'wcc/contentful/middleware'

# The root namespace of the wcc-contentful gem
#
# Initialize the gem with the `configure` and `init` methods inside your
# initializer.
module WCC::Contentful
  class << self
    attr_reader :initialized

    # Gets the current configuration, after calling WCC::Contentful.configure
    attr_reader :configuration

    def types
      WCC::Contentful.deprecator.warn('Use WCC::Contentful::Model.schema instead')
      WCC::Contentful::Model.schema
    end

    # Gets all queryable locales.
    def locales
      configuration&.locale_fallbacks
    end

    def logger
      WCC::Contentful.deprecator.warn('Use WCC::Contentful::Services.instance.logger instead')
      WCC::Contentful::Services.instance.logger
    end

    def deprecator
      @deprecator ||=
        begin
          next_major_version = WCC::Contentful::VERSION.split('.').first.next
          ActiveSupport::Deprecation.new(
            "#{next_major_version}.0",
            'wcc-contentful'
          )
        end
    end
  end

  # Configures the WCC::Contentful gem to talk to a Contentful space.
  # This must be called first in your initializer, before #init! or accessing the
  # client.
  # See WCC::Contentful::Configuration for all configuration options.
  def self.configure
    raise InitializationError, 'Cannot configure after initialization' if @initialized

    @configuration ||= Configuration.new
    yield(configuration)

    configuration.validate!

    configuration
  end

  # Initializes the WCC::Contentful model-space and backing store.
  # This populates the WCC::Contentful::Model namespace with Ruby classes
  # that represent content types in the configured Contentful space.
  #
  # These content types can be queried directly:
  #   WCC::Contentful::Model::Page.find('1xab...')
  # Or you can inherit from them in your own app:
  #   class Page < WCC::Contentful::Model::Page; end
  #   Page.find_by(slug: 'about-us')
  def self.init!
    raise InitializationError, 'Please first call WCC:Contentful.configure' if configuration.nil?
    raise InitializationError, 'Already Initialized' if @initialized

    if configuration.update_schema_file == :always ||
        (configuration.update_schema_file == :if_possible && Services.instance.management_client) ||
        (configuration.update_schema_file == :if_missing && !File.exist?(configuration.schema_file))

      begin
        downloader = WCC::Contentful::DownloadsSchema.new
        downloader.update! if configuration.update_schema_file == :always || downloader.needs_update?
      rescue WCC::Contentful::SimpleClient::ApiError => e
        raise InitializationError, e if configuration.update_schema_file == :always

        Services.instance.logger.warn("Unable to download schema from management API - #{e.message}")
      end
    end

    schema =
      begin
        JSON.parse(File.read(configuration.schema_file)) if File.exist?(configuration.schema_file)
      rescue JSON::ParserError
        Services.instance.warn("Schema file invalid, ignoring it: #{configuration.schema_file}")
        nil
      end

    content_types = schema['contentTypes'] if schema
    locales = schema['locales'] if schema

    if !schema && %i[if_possible never].include?(configuration.update_schema_file)
      # Final fallback - try to grab content types from CDN.  We can't update the file
      # because the CDN doesn't have all the field validation info, but we can at least
      # build the WCC::Contentful::Model instances.
      client = Services.instance.management_client ||
        Services.instance.client
      begin
        content_types = client.content_types(limit: 1000).items if client
      rescue WCC::Contentful::SimpleClient::ApiError => e
        # indicates bad credentials
        Services.instance.logger.warn("Unable to load content types from API - #{e.message}")
      end
    end

    unless content_types
      raise InitializationError, 'Unable to load content types from schema file or API! ' \
                                 'Check your access token and space ID.'
    end

    # Set the schema on the default WCC::Contentful::Model
    WCC::Contentful::Model.configure(
      configuration,
      schema: WCC::Contentful::ContentTypeIndexer.from_json_schema(content_types).types,
      services: WCC::Contentful::Services.instance
    )

    # Update the locale fallbacks from the schema file, unless they have already
    # been configured.
    locales&.each do |locale_hash|
      next if @configuration.locale_fallbacks[locale_hash['code']]

      @configuration.locale_fallbacks[locale_hash['code']] = locale_hash['fallbackCode']
    end

    # Enqueue an initial sync
    WCC::Contentful::SyncEngine::Job.perform_later if defined?(WCC::Contentful::SyncEngine::Job)

    @configuration = @configuration.freeze
    @initialized = true
  end
end

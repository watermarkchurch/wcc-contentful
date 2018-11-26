# frozen_string_literal: true

require 'wcc/contentful/version'

require 'active_support'
require 'active_support/core_ext/object'

require 'wcc/contentful/active_record_shim'
require 'wcc/contentful/configuration'
require 'wcc/contentful/downloads_schema'
require 'wcc/contentful/exceptions'
require 'wcc/contentful/helpers'
require 'wcc/contentful/services'
require 'wcc/contentful/simple_client'
require 'wcc/contentful/store'
require 'wcc/contentful/content_type_indexer'
require 'wcc/contentful/model'
require 'wcc/contentful/model_methods'
require 'wcc/contentful/model_singleton_methods'
require 'wcc/contentful/model_builder'

# The root namespace of the wcc-contentful gem
#
# Initialize the gem with the `configure` and `init` methods inside your
# initializer.
module WCC::Contentful
  class << self
    # Gets the current configuration, after calling WCC::Contentful.configure
    attr_reader :configuration

    attr_reader :types
  end

  # Configures the WCC::Contentful gem to talk to a Contentful space.
  # This must be called first in your initializer, before #init! or accessing the
  # client.
  # See WCC::Contentful::Configuration for all configuration options.
  def self.configure
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
    raise ArgumentError, 'Please first call WCC:Contentful.configure' if configuration.nil?

    if configuration.update_schema_file == :always ||
        (configuration.update_schema_file == :if_possible && Services.instance.management_client)

      begin
        downloader = WCC::Contentful::DownloadsSchema.new
        downloader.update! if configuration.update_schema_file == :always || downloader.needs_update?
      rescue WCC::Contentful::SimpleClient::ApiError => e
        raise InitializationError, e if configuration.update_schema_file == :always

        Rails.logger.warn("Unable to download schema from management API - #{e.message}")
      end
    end

    @content_types =
      begin
        if File.exist?(configuration.schema_file)
          JSON.parse(File.read(configuration.schema_file))['contentTypes']
        end
      rescue JSON::ParserError
        Rails.logger.warn("Schema file invalid, ignoring it: #{configuration.schema_file}")
        nil
      end

    if !@content_types && %i[if_possible never].include?(configuration.update_schema_file)
      # Final fallback - try to grab content types from CDN.  We can't update the file
      # because the CDN doesn't have all the field validation info, but we can at least
      # build the WCC::Contentful::Model instances.
      client = Services.instance.management_client ||
        Services.instance.client
      begin
        @content_types = client.content_types(limit: 1000).items if client
      rescue WCC::Contentful::SimpleClient::ApiError => e
        # indicates bad credentials
        Rails.logger.warn("Unable to load content types from API - #{e.message}")
      end
    end

    unless @content_types
      raise InitializationError, 'Unable to load content types from schema file or API!' \
        ' Check your access token and space ID.'
    end

    indexer =
      ContentTypeIndexer.new.tap do |ixr|
        @content_types.each { |type| ixr.index(type) }
      end
    @types = indexer.types

    store = Services.instance.store
    if store.respond_to?(:index)
      # Drop an initial sync
      WCC::Contentful::DelayedSyncJob.perform_later
    end

    WCC::Contentful::ModelBuilder.new(@types).build_models

    require_relative 'contentful/client_ext' if defined?(::Contentful)
  end
end

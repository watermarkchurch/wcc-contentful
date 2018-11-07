# frozen_string_literal: true

require 'wcc/contentful/version'

require 'active_support'
require 'active_support/core_ext/object'

require 'wcc/contentful/configuration'
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

    # we want as much as possible the raw JSON from the API so use the management
    # client if possible
    client = Services.instance.management_client ||
      Services.instance.client

    @content_types = client.content_types(limit: 1000).items

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

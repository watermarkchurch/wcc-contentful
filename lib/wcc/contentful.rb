# frozen_string_literal: true

require 'wcc/contentful/version'

require 'active_support'
require 'active_support/core_ext/object'

require 'wcc/contentful/configuration'
require 'wcc/contentful/exceptions'
require 'wcc/contentful/helpers'
require 'wcc/contentful/simple_client'
require 'wcc/contentful/store'
require 'wcc/contentful/content_type_indexer'
require 'wcc/contentful/model_validators'
require 'wcc/contentful/model'
require 'wcc/contentful/model_builder'

module WCC::Contentful
  class << self
    attr_reader :configuration
  end

  def self.client
    configuration&.client
  end

  def self.configure
    @configuration ||= Configuration.new
    yield(configuration)

    configuration.configure_contentful

    raise ArgumentError, 'Please provide "space" ID' unless configuration.space.present?
    raise ArgumentError, 'Please provide "access_token"' unless configuration.access_token.present?

    configuration
  end

  def self.init!
    raise ArgumentError, 'Please first call WCC:Contentful.configure' if configuration.nil?

    # we want as much as possible the raw JSON from the API
    content_types_resp =
      if configuration.management_client
        configuration.management_client.content_types(limit: 1000)
      else
        configuration.client.content_types(limit: 1000)
      end
    @content_types = content_types_resp.items

    indexer =
      ContentTypeIndexer.new.tap do |ixr|
        @content_types.each { |type| ixr.index(type) }
      end
    @types = indexer.types

    case configuration.content_delivery
    when :eager_sync
      store = configuration.sync_store

      client.sync(initial: true).items.each do |item|
        # TODO: enrich existing type data using Sync::Indexer
        store.index(item.dig('sys', 'id'), item)
      end
      WCC::Contentful::Model.store = store
    when :direct
      store = Store::CDNAdapter.new(client)
      WCC::Contentful::Model.store = store
    end

    WCC::Contentful::ModelBuilder.new(@types).build_models

    # Extend all model types w/ validation & extra fields
    @types.each_value do |t|
      file = File.dirname(__FILE__) + "/contentful/model/#{t.name.underscore}.rb"
      require file if File.exist?(file)
    end

    return unless defined?(Rails)
    Dir[Rails.root.join('lib/wcc/contentful/model/**/*.rb')].each { |file| require file }
  end

  def self.validate_models!
    schema =
      Dry::Validation.Schema do
        WCC::Contentful::Model.all_models.each do |klass|
          next unless klass.schema
          ct = klass.try(:content_type) || klass.name.demodulize
          required(ct).schema(klass.schema)
        end
      end

    content_types = WCC::Contentful::ModelValidators.transform_content_types_for_validation(
      @content_types
    )
    errors = schema.call(content_types)
    raise WCC::Contentful::ValidationError, errors.errors unless errors.success?
  end

  # TODO: https://zube.io/watermarkchurch/development/c/2234 init graphql
  # def self.init_graphql!
  #   require 'wcc/contentful/graphql'
  #   etc...
  # end
end

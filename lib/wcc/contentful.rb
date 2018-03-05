# frozen_string_literal: true

require 'wcc/contentful/version'
require 'wcc/contentful/configuration'
require 'contentful_model'

require 'wcc/contentful/helpers'
require 'wcc/contentful/store'
require 'wcc/contentful/sync'
require 'wcc/contentful/content_type_indexer'
require 'wcc/contentful_model'
require 'wcc/contentful/model_builder'

module WCC
  module Contentful
    class << self
      attr_reader :configuration
    end

    def self.client
      configuration&.client
    end

    def self.configure
      @configuration ||= Configuration.new
      yield(configuration)
      configuration.configure_contentful_model if defined?(::ContentfulModel)
      configuration
    end

    def self.init!
      raise ArgumentError, 'Please first call WCC:Contentful.Configure!' if configuration.nil?

      # TODO: figure out how to load these when ContentfulModel not present
      content_types =
        if configuration.management_token.present?
          # prefer from mgmt API since it has richer data
          ::ContentfulModel::Management.new.content_types
            .all(::ContentfulModel.configuration.space).map { |t| t }
        else
          client.dynamic_entry_cache
            .values.map(&:content_type)
        end

      types =
        ContentTypeIndexer.new.tap do |ixr|
          content_types.each { |type| ixr.index(type) }
        end

      case configuration.content_delivery
      when :eager_sync
        store = configuration.sync_store

        client.sync(initial: true).each_item do |item|
          # TODO: enrich existing type data using Sync::Indexer
          store.index(item.id, item.marshal_dump)
        end
        WCC::ContentfulModel.store = store
      when :direct
        store = Store::CDNAdapter.new(client)
        WCC::ContentfulModel.store = store
      end

      WCC::Contentful::ModelBuilder.new(types.types).build_models
    end
  end
end

require 'wcc/contentful/redirect'

require 'wcc/contentful/graphql'

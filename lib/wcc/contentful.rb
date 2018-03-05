# frozen_string_literal: true

require 'wcc/contentful/version'
require 'contentful_model'

require 'wcc/contentful/helpers'
require 'wcc/contentful/store'
require 'wcc/contentful/sync'
require 'wcc/contentful/content_type_indexer'
require 'wcc/contentful/model'
require 'wcc/contentful/model_builder'

module WCC
  module Contentful
    class << self
      attr_reader :configuration

      attr_reader :client
    end

    def self.configure
      @configuration ||= Configuration.new
      yield(configuration)

      if defined?(ContentfulModel)
        configuration.configure_contentful_model
        @client = ContentfulModel::Base.client
      elsif defined?(Contentful)
        @client = Contentful::Client.new(
          space: configuration.space,
          access_token: configuration.access_token
        )
      end
      configuration
    end

    class Configuration
      ATTRIBUTES = %i[
        access_token
        management_token
        space
        default_locale
      ].freeze
      attr_accessor(*ATTRIBUTES)

      def initialize
        @access_token = ''
        @management_token = ''
        @space = ''
        @default_locale = ''
      end

      def configure_contentful_model
        ContentfulModel.configure do |config|
          config.access_token = access_token
          config.management_token = management_token if management_token.present?
          config.space = space
          config.default_locale = default_locale
        end
      end
    end

    def self.init!
      raise ArgumentError, 'Please first call WCC:Contentful.Configure!' if configuration.nil?

      # TODO: figure out how to load these when ContentfulModel not present
      content_types =
        if configuration.management_token.present?
          # prefer from mgmt API since it has richer data
          ContentfulModel::Management.new.content_types
            .all(ContentfulModel.configuration.space).map { |t| t }
        else
          client.dynamic_entry_cache
            .values.map(&:content_type)
        end

      types =
        ContentTypeIndexer.new.tap do |ixr|
          content_types.each { |type| ixr.index(type) }
        end

      # TODO: allow configuration of which method & store to use
      store = Store::MemoryStore.new

      client.sync(initial: true).each_item do |item|
        # TODO: enrich existing type data using Sync::Indexer
        store.index(item.id, item.marshal_dump)
      end

      WCC::Contentful::Model.store = store
      WCC::Contentful::ModelBuilder.new(types.types).build_models
    end
  end
end

require 'wcc/contentful/redirect'

require 'wcc/contentful/graphql'

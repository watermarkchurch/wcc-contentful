# frozen_string_literal: true

require 'http'

class WCC::Contentful::Configuration
  ATTRIBUTES = %i[
    access_token
    management_token
    space
    default_locale
    content_delivery
    override_get_http
    preview_token
  ].freeze
  attr_accessor(*ATTRIBUTES)

  CDN_METHODS = [
    :eager_sync,
    # TODO: :lazy_sync
    :direct
  ].freeze

  SYNC_STORES = {
    memory: ->(_config) { WCC::Contentful::Store::MemoryStore.new },
    postgres: ->(_config) {
      require_relative 'store/postgres_store'
      WCC::Contentful::Store::PostgresStore.new(ENV['POSTGRES_CONNECTION'])
    }
  }.freeze

  def content_delivery=(symbol)
    raise ArgumentError, "Please set one of #{CDN_METHODS}" unless CDN_METHODS.include?(symbol)
    @content_delivery = symbol
  end

  def sync_store=(symbol)
    if symbol.is_a? Symbol
      unless SYNC_STORES.keys.include?(symbol)
        raise ArgumentError, "Please use one of #{SYNC_STORES.keys}"
      end
    end
    @sync_store = symbol
  end

  def sync_store
    @sync_store = SYNC_STORES[@sync_store].call(self) if @sync_store.is_a? Symbol
    @sync_store ||= Store::MemoryStore.new
  end

  # A proc which overrides the "get_http" function in Contentful::Client.
  # All interaction with Contentful will go through this function.
  # Should be a lambda like: ->(url, query, headers = {}, proxy = {}) { ... }
  attr_writer :override_get_http

  def initialize
    @access_token = ''
    @management_token = ''
    @preview_token = ''
    @space = ''
    @default_locale = nil
    @content_delivery = :direct
    @sync_store = :memory
  end

  attr_reader :client
  attr_reader :management_client
  attr_reader :preview_client

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
      default_locale: default_locale
    )
    if management_token.present?
      @management_client = WCC::Contentful::SimpleClient::Management.new(
        management_token: management_token,
        space: space,
        default_locale: default_locale
      )
    elsif preview_token.present?
      @preview_client = WCC::Contentful::SimpleClient::Preview.new(
        preview_token: preview_token,
        space: space,
        default_locale: default_locale
      )
    end
  end
end

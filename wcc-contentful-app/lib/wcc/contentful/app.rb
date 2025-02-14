# frozen_string_literal: true

require 'wcc/contentful/rails'

require_relative './app/rails'
require_relative './app/exceptions'
require_relative './app/configuration'
require_relative './app/markdown_renderer'

module WCC::Contentful::App
  class << self
    attr_reader :initialized

    # Gets the current configuration, after calling WCC::Contentful::App.configure
    attr_reader :configuration
  end

  def self.configure
    if initialized || WCC::Contentful.initialized
      raise WCC::Contentful::InitializationError, 'Cannot configure after initialization'
    end

    WCC::Contentful.configure do |wcc_contentful_config|
      if @configuration&.wcc_contentful_config != wcc_contentful_config
        @configuration = Configuration.new(wcc_contentful_config)
      end
      yield(configuration)
    end

    configuration.validate!

    configuration
  end

  def self.init!
    raise ArgumentError, 'Please first call WCC::Contentful::App.configure' if configuration.nil?

    WCC::Contentful.init!

    # Extend all model types w/ validation & extra fields
    WCC::Contentful::Model.schema.each_value do |t|
      file = File.dirname(__FILE__) + "/model/#{t.name.underscore}.rb"
      require file if File.exist?(file)
    end

    @db_connected =
      begin
        ::ActiveRecord::Base.connection_pool.with_connection(&:active?)
      rescue StandardError
        false
      end

    @configuration = WCC::Contentful::App::Configuration::FrozenConfiguration.new(
      configuration,
      WCC::Contentful.configuration
    )
    @initialized = true
  end
end

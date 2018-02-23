# frozen_string_literal: true

require 'wcc/contentful/version'
require 'contentful_model'

module WCC
  module Contentful
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
      Configuration.configure_contentful_model
    end

    class Configuration
      attr_accessor :access_token, :space, :default_locale

      def initialize
        @access_token = ''
        @space = ''
        @default_locale = ''
      end

      def self.configure_contentful_model
        ContentfulModel.configure do |config|
          config.access_token = WCC::Contentful.configuration.access_token
          config.space = WCC::Contentful.configuration.space
          config.default_locale = WCC::Contentful.configuration.default_locale
        end
      end
    end
  end
end

require 'wcc/contentful/redirect'

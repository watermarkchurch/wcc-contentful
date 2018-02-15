require "wcc/contentful/version"
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
        @access_token = ""
        @space = ""
        @default_locale = ""
      end

      def self.configure_contentful_model
        ContentfulModel.configure do |config|
          config.access_token = WCC::Contentful.configuration.access_token
          config.space = WCC::Contentful.configuration.space
          config.default_locale = WCC::Contentful.configuration.default_locale
        end
      end
    end

    class Redirect < ContentfulModel::Base
      return_nil_for_empty :url, :pageReference
      class_attribute :load_depth
      self.load_depth = 10
      self.content_type_id = 'redirect'

      def self.find_by_slug(slug)
        self.find_by(slug: slug).load_children(load_depth).load.first
      end

      def location
        if !self.url.nil?
          return self.url
        elsif !self.pageReference.nil?
          return "/#{self.pageReference.url}"
        else
          return nil
        end
      end
    end

  end
end

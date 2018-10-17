# frozen_string_literal: true

require_relative './app/rails'
require_relative './app/exceptions'
require_relative './app/model_validators'
require_relative './ext/model'

module WCC::Contentful::App
  def self.init!
    raise ArgumentError, 'Please first call WCC::Contentful.init!' unless WCC::Contentful.types

    # TODO: figure out why MenuHelper isn't autoloading
    ActionView::Base.__send__ :include, MenuHelper

    # Extend all model types w/ validation & extra fields
    WCC::Contentful.types.each_value do |t|
      file = File.dirname(__FILE__) + "/model/#{t.name.underscore}.rb"
      require file if File.exist?(file)
    end
  end
end

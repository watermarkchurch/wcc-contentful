# frozen_string_literal: true

require 'wcc/contentful/rails'

require_relative './app/rails'
require_relative './app/exceptions'
require_relative './app/model_validators'
require_relative './ext/model'

module WCC::Contentful::App
  def self.init!
    raise ArgumentError, 'Please first call WCC::Contentful.init!' unless WCC::Contentful.types

    # Extend all model types w/ validation & extra fields
    WCC::Contentful.types.each_value do |t|
      file = File.dirname(__FILE__) + "/model/#{t.name.underscore}.rb"
      require file if File.exist?(file)
    end

    @db_connected =
      begin
        ::ActiveRecord::Base.connection_pool.with_connection(&:active?)
      rescue StandardError
        false
      end
  end

  def self.db_connected?
    @db_connected
  end
end

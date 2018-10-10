# frozen_string_literal: true

require_relative './contentful_ext/exceptions'
require_relative './contentful/model_validators'
require_relative './contentful_ext/model'

module WCC::Cms
  def self.init!
    raise ArgumentError, 'Please first call WCC::Contentful.init!' unless WCC::Contentful.types

    # Extend all model types w/ validation & extra fields
    WCC::Contentful.types.each_value do |t|
      file = File.dirname(__FILE__) + "/contentful/model/#{t.name.underscore}.rb"
      require file if File.exist?(file)
    end
  end
end

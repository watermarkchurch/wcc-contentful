
# frozen_string_literal: true

class WCC::Contentful::Model
  extend WCC::Contentful::Helpers
  extend WCC::Contentful::ModelValidators

  class << self
    attr_accessor :store
    attr_accessor :preview_store
  end

  def self.all_models
    WCC::Contentful::Model.constants(false).map { |k| WCC::Contentful::Model.const_get(k) }
  end

  def self.find(id, context = nil)
    return unless raw = store.find(id)

    content_type = content_type_from_raw(raw)

    const = WCC::Contentful::Model.const_get(constant_from_content_type(content_type))
    const.new(raw, context)
  end
end

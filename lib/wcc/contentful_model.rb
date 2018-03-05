
# frozen_string_literal: true

class WCC::ContentfulModel
  extend WCC::Contentful::Helpers

  class << self
    attr_accessor :store
  end

  def self.all_models
    subclasses
  end

  def self.find(id, context = nil)
    return unless raw = store.find(id)

    content_type = content_type_from_raw(raw)

    const = WCC::ContentfulModel.const_get(constant_from_content_type(content_type))
    const.new(raw, context)
  end
end


# frozen_string_literal: true

module WCC::Contentful
  class Model
    class << self
      include Helpers

      attr_accessor :store
    end

    def self.all_models
      Model.subclasses
    end

    def self.find(id, context = nil)
      raw = store.find(id)
      content_type = content_type_from_raw(raw)

      const = WCC::Contentful.const_get(constant_from_content_type(content_type))
      const.new(raw, context)
    end
  end
end

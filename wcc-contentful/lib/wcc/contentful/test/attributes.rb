# frozen_string_literal: true

module WCC::Contentful::Test::Attributes
  DEFAULTS = {
    String: 'test',
    Int: 0,
    Float: 0.0,
    DateTime: Time.at(0),
    Boolean: false,
    Json: -> { OpenStruct.new },
    Coordinates: -> { OpenStruct.new }
  }.freeze

  class << self
    def [](key)
      DEFAULTS[key]
    end

    ##
    # Get a hash of default values for all attributes unique to the given Contentful model.
    def defaults(const)
      unless const < WCC::Contentful::Model
        raise ArgumentError, "#{const} is not a subclass of WCC::Contentful::Model"
      end

      const.content_type_definition.fields.each_with_object({}) do |(name, f), h|
        h[name.to_sym] = h[name.underscore.to_sym] = default_value(f)
      end
    end

    ##
    # Gets the default value for a contentful IndexedRepresentation::Field.
    # This comes from the 'content_type_definition' of a contentful model class.
    def default_value(field)
      return [] if field.array
      return unless field.required

      val = DEFAULTS[field]
      return val.call if val.respond_to?(:call)

      val
    end
  end
end

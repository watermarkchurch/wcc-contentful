# frozen_string_literal: true

require_relative './attributes'

module WCC::Contentful::Test::Factory
  ##
  # Builds a in-memory instance of the Contentful model for the given content_type.
  # All attributes that are known to be required fields on the content type
  # will return a default value based on the field type.
  def contentful_create(const, context = nil, **attrs)
    unless const.respond_to?(:content_type_definition)
      const = WCC::Contentful::Model.resolve_constant(const.to_s)
    end
    attrs = attrs.transform_keys { |a| a.to_s.camelize(:lower) }

    id = attrs.delete('id')
    sys = attrs.delete('sys')
    raw = attrs.delete('raw') || default_raw(const, id)
    bad_attrs = attrs.reject { |a| const.content_type_definition.fields.key?(a) }
    raise ArgumentError, "Attribute(s) do not exist on #{const}: #{bad_attrs.keys}" if bad_attrs.any?

    raw['sys'].merge!(sys) if sys

    attrs.each do |k, v|
      field = const.content_type_definition.fields[k]

      raw_value = v
      raw_value = to_raw(v, field.type) if %i[Asset Link].include?(field.type)
      raw['fields'][field.name][raw.dig('sys', 'locale')] = raw_value
    end

    instance = const.new(raw, context)

    attrs.each do |k, v|
      field = const.content_type_definition.fields[k]
      next unless %i[Asset Link].include?(field.type)

      unless field.array ? v.any? { |i| i.is_a?(String) } : v.is_a?(String)
        instance.instance_variable_set("@#{field.name}_resolved", v)
      end
    end

    instance
  end

  private

  def default_instance(model, id = nil)
    model.new(default_raw(model, id))
  end

  def default_raw(model, id = nil)
    { sys: contentful_sys(model, id), fields: contentful_fields(model) }.as_json
  end

  def contentful_sys(model, id = nil)
    {
      space: {
        sys: {
          type: 'Link',
          linkType: 'Space',
          id: ENV['CONTENTFUL_SPACE_ID']
        }
      },
      id: id || SecureRandom.urlsafe_base64,
      type: 'Entry',
      createdAt: Time.now.to_s(:iso8601),
      updatedAt: Time.now.to_s(:iso8601),
      environment: {
        sys: {
          id: 'master',
          type: 'Link',
          linkType: 'Environment'
        }
      },
      revision: rand(100),
      contentType: {
        sys: {
          type: 'Link',
          linkType: 'ContentType',
          id: model.content_type
        }
      },
      locale: 'en-US'
    }
  end

  def contentful_fields(model)
    WCC::Contentful::Test::Attributes.defaults(model).each_with_object({}) do |(k, v), h|
      h[k] = { 'en-US' => v }
    end
  end

  def to_raw(val, field_type)
    if val.is_a? Array
      val.map { |i| to_raw(i, field_type) }
    elsif val.is_a? String
      WCC::Contentful::Link.new(val, field_type).raw
    elsif val
      val.raw
    end
  end
end

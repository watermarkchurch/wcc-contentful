# frozen_string_literal: true

require_relative './attributes'

module WCC::Contentful::Test::Factory
  ##
  # Builds a in-memory instance of the Contentful model for the given content_type.
  # All attributes that are known to be required fields on the content type
  # will return a default value based on the field type.
  def contentful_create(content_type, **attrs)
    const = WCC::Contentful::Model.resolve_constant(content_type.to_s)
    attrs = attrs.transform_keys { |a| a.to_s.camelize(:lower) }

    id = attrs.delete('id')
    bad_attrs = attrs.reject { |a| const.content_type_definition.fields.key?(a) }
    raise ArgumentError, "Attribute(s) do not exist on #{const}: #{bad_attrs.keys}" if bad_attrs.any?

    default_instance(const, id).tap do |instance|
      attrs.each do |k, v|
        field = const.content_type_definition.fields[k]

        raw = v
        if %i[Asset Link].include?(field.type)
          raw = to_raw(v, field.type)

          unless field.array ? v.any? { |i| i.is_a?(String) } : v.is_a?(String)
            instance.instance_variable_set("@#{field.name}_resolved", v)
          end
        end

        instance.raw['fields'][field.name][instance.sys.locale] = raw
        instance.instance_variable_set("@#{field.name}", raw)
      end

      def instance.to_s
        "#<#{self.class.name} id=\"#{id}\">"
      end
    end
  end

  class Link
    attr_reader :id
    attr_reader :link_type
    attr_reader :raw

    LINK_TYPES = {
      Asset: 'Asset',
      Link: 'Entry'
    }.freeze

    def initialize(model, link_type = nil)
      @id = model.try(:id) || model
      @link_type = link_type
      @link_type ||= model.is_a?(WCC::Contentful::Model::Asset) ? :Asset : :Link
      @raw =
        {
          'sys' => {
            'type' => 'Link',
            'linkType' => LINK_TYPES[@link_type],
            'id' => @id
          }
        }
    end

    alias_method :to_h, :raw
  end

  private

  def default_instance(model, id = nil)
    model.new(default_raw(model, id))
  end

  def default_raw(model, id = nil)
    { sys: sys(model, id), fields: fields(model) }.as_json
  end

  def sys(model, id = nil)
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

  def fields(model)
    WCC::Contentful::Test::Attributes.defaults(model).each_with_object({}) do |(k, v), h|
      h[k] = { 'en-US' => v }
    end
  end

  def to_raw(val, field_type)
    if val.is_a? Array
      val.map { |i| to_raw(i, field_type) }
    elsif val.is_a? String
      Link.new(val, field_type).raw
    elsif val
      val.raw
    end
  end
end

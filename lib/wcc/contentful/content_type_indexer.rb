# frozen_string_literal: true

require_relative 'indexed_representation'

module WCC::Contentful
  class ContentTypeIndexer
    include WCC::Contentful::Helpers

    attr_reader :types

    def initialize
      @types = IndexedRepresentation.new({
        'Asset' => create_asset_type
      })
    end

    def index(content_type)
      content_type =
        if content_type.is_a?(Contentful::ContentType) ||
            content_type.is_a?(Contentful::Management::ContentType)
          create_type(content_type.id, content_type.fields)
        else
          create_type(content_type.dig('sys', 'id'), content_type['fields'])
        end

      @types[content_type.content_type] = content_type
    end

    def create_type(content_type_id, fields)
      content_type = IndexedRepresentation::ContentType.new({
        name: constant_from_content_type(content_type_id),
        content_type: content_type_id
      })

      fields.each do |f|
        field = create_field(f)
        content_type.fields[field.name] = field
      end

      content_type
    end

    # hardcoded because the Asset type is a "magic type" in their system
    def create_asset_type
      IndexedRepresentation::ContentType.new({
        name: 'Asset',
        content_type: 'Asset',
        fields: {
          'title' => { name: 'title', type: :String },
          'description' => { name: 'description', type: :String },
          'file' => { name: 'file', type: :Json }
        }
      })
    end

    private

    def create_field(field)
      if field.respond_to?(:raw)
        create_field_from_raw(field.raw)
      elsif field.respond_to?(:to_h)
        create_field_from_raw(field.to_h)
      else
        create_field_from_managed(field)
      end
    end

    def create_field_from_managed(managed_field)
      field = IndexedRepresentation::Field.new({
        name: managed_field.id,
        type: find_field_type(managed_field),
        required: managed_field.required
      })
      field.array = true if managed_field.type == 'Array'

      if field.type == :Link
        validations =
          if field.array
            managed_field.items.validations
          else
            managed_field.validations
          end
        field.link_types = resolve_managed_link_types(validations) if validations.present?
      end
      field
    end

    def create_field_from_raw(raw_field)
      field_name = raw_field['id']
      field = IndexedRepresentation::Field.new({
        name: field_name,
        type: find_field_type(raw_field),
        required: raw_field['required']
      })
      field.array = true if raw_field['type'] == 'Array'

      if field.type == :Link
        validations =
          if field.array
            raw_field.dig('items', 'validations')
          else
            raw_field['validations']
          end
        field.link_types = resolve_raw_link_types(validations) if validations.present?
      end
      field
    end

    def find_field_type(field)
      # 'Symbol' | 'Text' | 'Integer' | 'Number' | 'Date' | 'Boolean' |
      #  'Object' | 'Location' | 'Array' | 'Link'
      case raw_type = field.try(:type) || field['type']
      when 'Symbol', 'Text'
        :String
      when 'Integer'
        :Int
      when 'Number'
        :Float
      when 'Date'
        :DateTime
      when 'Boolean'
        :Boolean
      when 'Object'
        :Json
      when 'Location'
        :Coordinates
      when 'Array'
        find_field_type(field.try(:items) || field['items'])
      when 'Link'
        case link_type = field.try(:link_type) || field['linkType']
        when 'Entry'
          :Link
        when 'Asset'
          :Asset
        else
          raise ArgumentError,
            "Unknown link type #{link_type} for field #{field.try(:id) || field['id']}"
        end
      else
        raise ArgumentError, "unknown field type #{raw_type} for field #{field.try(:id) || field['id']}"
      end
    end

    def resolve_managed_link_types(validations)
      validation = validations.find { |v| v.link_content_type.present? }
      validation.link_content_type if validation.present?
    end

    def resolve_raw_link_types(validations)
      validation = validations.find { |v| v['linkContentType'].present? }
      validation['linkContentType'] if validation.present?
    end
  end
end

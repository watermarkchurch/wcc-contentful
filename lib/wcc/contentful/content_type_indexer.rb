# frozen_string_literal: true

module WCC::Contentful
  class ContentTypeIndexer
    include WCC::Contentful::Helpers

    attr_reader :types

    def initialize
      @types = {
        'Asset' => create_asset_type
      }
    end

    def index(raw_content_type)
      content_type =
        if raw_content_type.is_a?(Contentful::ContentType)
          create_type_from_raw(raw_content_type.id, raw_content_type.fields.map(&:raw))
        else
          create_type_from_raw(raw_content_type.dig('sys', 'id'), raw_content_type['fields'])
        end

      @types[content_type[:name]] = content_type
    end

    def create_type_from_raw(content_type_id, raw_fields)
      content_type = {
        name: constant_from_content_type(content_type_id),
        content_type: content_type_id,
        fields: {}
      }

      raw_fields.each do |raw_field|
        field_name = raw_field['id']
        field = {
          name: field_name,
          type: find_field_type(raw_field),
          required: raw_field['required']
        }
        field[:array] = true if raw_field['type'] == 'Array'

        if field[:type] == :Link
          validations =
            if field[:array]
              raw_field.dig('items', 'validations')
            else
              raw_field['validations']
            end
          field[:link_types] = resolve_link_types(validations) if validations.present?
        end

        content_type[:fields][field_name] = field
      end

      content_type
    end

    def create_asset_type
      {
        name: 'Asset',
        content_type: 'Asset',
        fields: {
          'title' => { name: 'title', type: :String },
          'description' => { name: 'description', type: :String },
          'file' => { name: 'file', type: :Json }
        }
      }
    end

    private

    def find_field_type(raw_field)
      # 'Symbol' | 'Text' | 'Integer' | 'Number' | 'Date' | 'Boolean' |
      #  'Object' | 'Location' | 'Array' | 'Link'
      case raw_field['type']
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
        find_field_type(raw_field['items'])
      when 'Link'
        case raw_field['linkType']
        when 'Entry'
          :Link
        when 'Asset'
          :Asset
        else
          raise ArgumentError, "Unknown link type #{raw_field['linkType']} for field #{raw_field['id']}"
        end
      else
        raise ArgumentError, "unknown field type #{raw_type} for field #{raw_field['id']}"
      end
    end

    def resolve_link_types(validations)
      validation = validations.find { |v| v['linkContentType'].present? }
      validation['linkContentType'].map { |ct| constant_from_content_type(ct) } if validation.present?
    end
  end
end

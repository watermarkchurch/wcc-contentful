# frozen_string_literal: true

module WCC::Contentful::Graphql::FieldHelper
  extend self

  def contentful_field_resolver(field_name)
    field_name = field_name.to_s

    ->(obj, _args, ctx) {
      if obj.is_a? Array
        obj.map { |o| o.dig('fields', field_name, ctx[:locale] || 'en-US') }
      else
        obj.dig('fields', field_name, ctx[:locale] || 'en-US')
      end
    }
  end

  def contentful_field(field_name, type, array: false, &block)
    field_name = field_name.to_s

    type =
      case type
      when :DateTime
        types.String
      when :Coordinates
        WCC::Contentful::Graphql::Types::CoordinatesType
      when :Json
        WCC::Contentful::Graphql::Types::HashType
      else
        if type.is_a?(Symbol) || type.is_a?(String)
          types.public_send(type)
        elsif type.is_a?(GraphQL::BaseType)
          type
        else
          raise ArgumentError, "Unknown type arg '#{type}' for field #{field_name}"
        end
      end
    type = type.to_list_type if array
    field(field_name.to_sym, type) do
      resolve contentful_field_resolver(field_name)

      instance_exec(&block) if block_given?
    end
  end

  def contentful_link_resolver(field_name, store:)
    ->(obj, _args, ctx) {
      links = obj.dig('fields', field_name, ctx[:locale] || 'en-US')
      return if links.nil?

      if links.is_a? Array
        links.reject(&:nil?).map { |l| store.find(l.dig('sys', 'id')) }
      else
        store.find(links.dig('sys', 'id'))
      end
    }
  end
end

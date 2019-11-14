# frozen_string_literal: true

module WCC::Contentful::Graphql::FieldHelper
  extend self

  def contentful_field_resolver(field_name)
    field_name = field_name.to_s

    resolver =
      ->(obj, args, ctx) {
        next obj.map { |o| resolver.call(o, args, ctx) } if obj.is_a? Array

        result =
          if obj.key?(field_name)
            obj.dig(field_name)
          else
            obj.dig('fields', field_name)
          end
        locale = ctx[:locale] || 'en-US'
        result = result[locale] if result.try(:key?, locale)
        result
      }

    resolver
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
    finder =
      ->(link) do
        next link unless id = link.try(:dig, 'sys', 'id')

        store.find(id)
      end

    ->(obj, _args, ctx) {
      links =
        if obj.key?(field_name)
          obj[field_name]
        else
          obj.dig('fields', field_name)
        end
      return if links.nil?

      locale = ctx[:locale] || 'en-US'
      links = links[locale] if links.key?(locale)

      if links.is_a? Array
        links.reject(&:nil?).map(&finder)
      else
        finder.call(links)
      end
    }
  end
end

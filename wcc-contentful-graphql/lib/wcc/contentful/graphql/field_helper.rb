# frozen_string_literal: true

module WCC::Contentful::Graphql
  module FieldHelper
    extend self

    def contentful_field(field_name, type, array: false, null: true)
      field_name = field_name.to_s
      type = contentful_field_type(type, array: array)

      field field_name.to_sym, type,
        null: null,
        resolver: WCC::Contentful::Graphql::Resolvers.field_resolver(field_name)

      # field(field_name.to_sym, type) do
      #   resolve contentful_field_resolver(field_name)

      #   instance_exec(&block) if block_given?
      # end
    end

    def contentful_field_type(type, array: false)
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
            GraphQL::Types.const_get(type)
          elsif type.is_a?(GraphQL::BaseType)
            type
          else
            raise ArgumentError, "Unknown type arg '#{type}' for field #{field_name}"
          end
        end
      type = type.to_list_type if array
      type
    end
  end
end

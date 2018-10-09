# frozen_string_literal: true

module WCC::Contentful::Graphql::Types
  DateTimeType =
    GraphQL::ScalarType.define do
      name 'DateTime'

      coerce_result ->(value, _ctx) { Time.zone.parse(value) }
    end

  HashType =
    GraphQL::ScalarType.define do
      name 'Hash'

      coerce_result ->(value, _ctx) {
        return value if value.is_a? Array
        return value.to_h if value.respond_to?(:to_h)
        return JSON.parse(value) if value.is_a? String

        raise ArgumentError, "Cannot coerce value '#{value}' to a hash"
      }
    end

  CoordinatesType =
    GraphQL::ObjectType.define do
      name 'Coordinates'

      field :lat, !types.Float, hash_key: 'lat'
      field :lon, !types.Float, hash_key: 'lon'
    end

  AnyScalarInputType =
    GraphQL::ScalarType.define do
      name 'Any'
    end

  FilterType =
    GraphQL::InputObjectType.define do
      name 'filter'

      argument :field, !types.String
      argument :eq, AnyScalarInputType
    end

  BuildUnionType =
    ->(from_types, union_type_name) do
      possible_types = from_types.values.reject { |t| t.is_a? GraphQL::UnionType }

      GraphQL::UnionType.define do
        name union_type_name
        possible_types possible_types
      end
    end
end

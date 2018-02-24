
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

  AnyScalarType =
    GraphQL::UnionType.define do
      name 'Any'

      possible_types [GraphQL::STRING_TYPE, GraphQL::INT_TYPE, GraphQL::FLOAT_TYPE, GraphQL::BOOLEAN_TYPE]
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
end

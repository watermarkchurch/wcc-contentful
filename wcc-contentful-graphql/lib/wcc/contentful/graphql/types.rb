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

  StringQueryOperatorInput =
    GraphQL::InputObjectType.define do
      name 'StringQueryOperatorInput'

      argument :eq, types.String
      # TODO: WCC::Contentful::Store::Base::Query::OPERATORS
      # ne
      # all
      # in
      # nin
      # exists
      # lt
      # lte
      # gt
      # gte
      # query
      # match
    end

  QueryOperatorInput =
    ->(type) do
      next QueryOperatorInput.call(type.of_type) if type.respond_to?(:of_type)

      map = {
        'GraphQL::Types::String' => StringQueryOperatorInput
        # 'Int' =>
        # 'Boolean' =>
      }

      map[type.unwrap.name]
    end

  FilterInputType =
    ->(schema_type) do
      GraphQL::InputObjectType.define do
        name "#{schema_type.name.demodulize}FilterInput"

        schema_type.fields.each do |(name, field)|
          next unless input_type = QueryOperatorInput.call(field.type)

          argument name, input_type
        end
      end
    end

  module Generated
    # Filled in by the Builder
  end
end

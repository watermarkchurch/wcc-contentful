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
    end

  QueryOperatorInput =
    ->(type) do
      puts
      next QueryOperatorInput.call(type.of_type) if type.respond_to?(:of_type)
      next type if type.try(:<, GraphQL::Schema::Scalar)

      map = {
        'String' => StringQueryOperatorInput
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
          input_type = QueryOperatorInput.call(field.type)
          next unless input_type

          argument name, input_type
        end
      end
    end

  BuildUnionType =
    ->(from_types, union_type_name) do
      possible_types = from_types.values.reject { |t| t.is_a? GraphQL::UnionType }

      GraphQL::UnionType.define do
        name union_type_name
        possible_types possible_types
      end
    end

  module Generated
    # Filled in by the Builder
  end
end

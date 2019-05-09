# frozen_string_literal: true

require 'graphql'

require_relative 'types'

module WCC::Contentful::Graphql
  class Builder
    attr_reader :schema_types
    attr_reader :root_types

    def initialize(types, store)
      @types = types
      @store = store

      @schema_types = build_schema_types
      @root_types = @schema_types.dup
    end

    def configure(&block)
      instance_exec(&block)
      self
    end

    def build_schema
      root_query_type = build_root_query(root_types)

      builder = self
      GraphQL::Schema.define do
        query root_query_type

        resolve_type ->(_type, obj, _ctx) {
          content_type = WCC::Contentful::Helpers.content_type_from_raw(obj)
          builder.schema_types[content_type]
        }
      end
    end

    private

    def build_root_query(schema_types)
      store = @store

      GraphQL::ObjectType.define do
        name 'Query'
        description 'The query root of this schema'

        schema_types.each do |content_type, schema_type|
          field schema_type.name.to_sym do
            type schema_type
            argument :id, types.ID
            description "Find a #{schema_type.name}"

            schema_type.fields.each do |(name, field)|
              next unless input_type = Types::QueryOperatorInput.call(field.type)

              argument name, input_type
            end

            resolve ->(_obj, args, _ctx) {
              if args['id'].nil?
                store.find_by(content_type: content_type, filter: args.to_h)
              else
                store.find(args['id'])
              end
            }
          end

          field "all#{schema_type.name}".to_sym do
            type schema_type.to_list_type
            argument :filter, Types::FilterInputType.call(schema_type)

            resolve ->(_obj, args, ctx) {
              relation = store.find_all(content_type: content_type)
              relation = relation.apply(args[:filter].to_h, ctx) if args[:filter]
              relation.to_enum
            }
          end
        end
      end
    end

    def build_schema_types
      @types.each_with_object({}) do |(k, v), h|
        h[k] = build_schema_type(v)
      end
    end

    def build_schema_type(typedef)
      store = @store
      builder = self
      content_type = typedef.content_type

      GraphQL::ObjectType.define do
        name(typedef.name)

        description("Generated from content type #{content_type}")

        field :id, !types.ID do
          resolve ->(obj, _args, _ctx) {
            obj.dig('sys', 'id')
          }
        end

        field :_content_type, !types.String do
          resolve ->(_, _, _) {
            content_type
          }
        end

        # Make a field for each column:
        typedef.fields.each_value do |f|
          case f.type
          when :Asset
            field(f.name.to_sym, -> {
              type = builder.schema_types['Asset']
              type = type.to_list_type if f.array
              type
            }) do
              resolve ->(obj, _args, ctx) {
                links = obj.dig('fields', f.name, ctx[:locale] || 'en-US')
                return if links.nil?

                if links.is_a? Array
                  links.reject(&:nil?).map { |l| store.find(l.dig('sys', 'id')) }
                else
                  store.find(links.dig('sys', 'id'))
                end
              }
            end
          when :Link
            field(f.name.to_sym, -> {
              type =
                if f.link_types.nil? || f.link_types.empty?
                  builder.schema_types['AnyContentful'] ||=
                    Types::BuildUnionType.call(builder.schema_types, 'AnyContentful')
                elsif f.link_types.length == 1
                  builder.schema_types[f.link_types.first]
                else
                  from_types = builder.schema_types.select { |key| f.link_types.include?(key) }
                  name = "#{typedef.name}_#{f.name}"
                  builder.schema_types[name] ||= Types::BuildUnionType.call(from_types, name)
                end
              type = type.to_list_type if f.array
              type
            }) do
              resolve ->(obj, _args, ctx) {
                links = obj.dig('fields', f.name, ctx[:locale] || 'en-US')
                return if links.nil?

                if links.is_a? Array
                  links.reject(&:nil?).map { |l| store.find(l.dig('sys', 'id')) }
                else
                  store.find(links.dig('sys', 'id'))
                end
              }
            end
          else
            type =
              case f.type
              when :DateTime
                Types::DateTimeType
              when :Coordinates
                Types::CoordinatesType
              when :Json
                Types::HashType
              else
                types.public_send(f.type)
              end
            type = type.to_list_type if f.array
            field(f.name.to_sym, type) do
              resolve ->(obj, _args, ctx) {
                if obj.is_a? Array
                  obj.map { |o| o.dig('fields', f.name, ctx[:locale] || 'en-US') }
                else
                  obj.dig('fields', f.name, ctx[:locale] || 'en-US')
                end
              }
            end
          end
        end
      end
    end
  end
end

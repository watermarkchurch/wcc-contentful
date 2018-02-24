# frozen_string_literal: true

require 'singleton'
require 'graphql'

require_relative 'types'

module WCC::Contentful::Graphql
  class Builder
    def initialize(types, store)
      @types = types
      @store = store
    end

    def build_schema
      schema_types = build_schema_types

      root_query_type = build_root_query(schema_types)

      GraphQL::Schema.define do
        query root_query_type
      end
    end

    private

    def build_root_query(schema_types)
      store = @store

      GraphQL::ObjectType.define do
        name 'Query'
        description 'The query root of this schema'

        schema_types.each_value do |pair|
          raw = pair[:raw]
          schema_type = pair[:typed]

          field schema_type.name.to_sym do
            type schema_type
            argument :id, types.ID
            description "Find a #{schema_type.name} by ID"

            resolve ->(_obj, args, _ctx) {
              if args['id'].nil?
                store.find_by(content_type: raw[:content_type]).first
              else
                store.find(args['id'])
              end
            }
          end

          field "all#{schema_type.name}".to_sym do
            type schema_type.to_list_type
            argument :filter, Types::FilterType

            resolve ->(_obj, args, ctx) {
              relation = store.find_by(content_type: raw[:content_type])
              relation = relation.apply(args[:filter], ctx) if args[:filter]
              relation.relation
            }
          end
        end
      end
    end

    def build_schema_types
      @types.each_with_object({}) do |(k, v), h|
        h[k] = {
          raw: v,
          typed: build_schema_type(v)
        }
      end
    end

    def build_schema_type(v)
      GraphQL::ObjectType.define do
        name(v[:name])
        description('Generated from Contentful schema')

        field :id, !types.ID do
          resolve ->(obj, _args, _ctx) {
            obj.dig('sys', 'id')
          }
        end
        field :content_type, !types.String

        # Make a field for each column:
        v[:fields].each_value do |f|
          case f[:type]
          when :Asset
            # todo
            next
          when :Link
            next
          when :DateTime
            field(f[:name].to_sym, Types::DateTimeType) do
              resolve ->(obj, _args, ctx) {
                obj.dig('fields', f[:name], ctx[:locale] || 'en-US')
              }
            end
          when :Location
            next
          when :Json
            field(f[:name].to_sym, Types::HashType) do
              resolve ->(obj, _args, ctx) {
                obj.dig('fields', f[:name], ctx[:locale] || 'en-US')
              }
            end
          else
            field(f[:name].to_sym, types.public_send(f[:type])) do
              resolve ->(obj, _args, ctx) {
                obj.dig('fields', f[:name], ctx[:locale] || 'en-US')
              }
            end
          end
        end
      end
    end
  end
end

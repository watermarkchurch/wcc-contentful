# frozen_string_literal: true

require 'graphql'

require_relative 'types'

module WCC::Contentful::Graphql
  class Builder
    attr_reader :schema_types

    def initialize(types, store)
      @types = types
      @store = store
    end

    def build_schema
      @schema_types = build_schema_types

      root_query_type = build_root_query(@schema_types)

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
              relation.result
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
      store = @store
      builder = self

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
            field(f[:name].to_sym, -> {
              type = builder.schema_types['ContentfulAsset'][:typed]
              type = type.to_list_type if f[:array]
              type
            }) do
              resolve ->(obj, _args, ctx) {
                links = obj.dig('fields', f[:name], ctx[:locale] || 'en-US')
                return if links.nil?

                if links.is_a? Array
                  links.reject(&:nil?).map { |l| store.find(l.dig('sys', 'id')) }
                else
                  store.find(links.dig('sys', 'id'))
                end
              }
            end
          when :Link
            field(f[:name].to_sym, -> {
              # TODO: Sections w/ a Union Type
              type = builder.schema_types[f[:link_types].first][:typed]
              type = type.to_list_type if f[:array]
              type
            }) do
              resolve ->(obj, _args, ctx) {
                links = obj.dig('fields', f[:name], ctx[:locale] || 'en-US')
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
              case f[:type]
              when :DateTime
                Types::DateTimeType
              when :Location
                Types::LocationType
              when :Json
                Types::HashType
              else
                types.public_send(f[:type])
              end
            type = type.to_list_type if f[:array]
            field(f[:name].to_sym, type) do
              resolve ->(obj, _args, ctx) {
                if obj.is_a? Array
                  obj.map { |o| o.dig('fields', f[:name], ctx[:locale] || 'en-US') }
                else
                  obj.dig('fields', f[:name], ctx[:locale] || 'en-US')
                end
              }
            end
          end
        end
      end
    end
  end
end

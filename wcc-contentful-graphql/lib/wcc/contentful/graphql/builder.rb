# frozen_string_literal: true

require 'graphql'

require_relative 'types'
require_relative 'resolvers'
require_relative 'field_helper'

GraphQL::Define::DefinedObjectProxy.__send__(:include, WCC::Contentful::Graphql::FieldHelper)

module WCC::Contentful::Graphql
  class Builder
    attr_reader :root_module

    def root_module=(new_module)
      @root_module = new_module
      @generated_module = nil
      @schema_types = nil
      @root_types = nil
      @base_field = nil
      @base_object = nil
      @base_interface = nil
      @base_schema = nil
    end

    attr_writer :generated_module
    def generated_module
      @generated_module ||= _get_or_create('Generated') { Module.new }
    end

    attr_writer :base_field, :base_object, :base_schema, :base_interface
    def base_field
      @base_field ||= _get_or_create('BaseField') { Class.new(GraphQL::Schema::Field) }
    end

    def base_object
      field = base_field
      @base_object ||=
        _get_or_create('BaseObject') do
          Class.new(GraphQL::Schema::Object) do
            field_class field
          end
        end
    end

    def base_interface
      field = base_field
      @base_interface ||=
        _get_or_create('BaseInterface') do
          Module.new do
            include GraphQL::Schema::Interface
            field_class field
          end
        end
    end

    def base_schema
      @base_schema ||= _get_or_create('BaseSchema') { Class.new(GraphQL::Schema) }
    end

    def schema_types
      _types = @types
      # types have to be built on-demand since we may have circular references
      @schema_types ||=
        Hash.new do |h, k|
          h[k] = build_schema_type(_types[k])
        end
    end

    def root_types
      @root_types ||= @types.keys
    end

    def initialize(types, store)
      @types = types if types.is_a? WCC::Contentful::IndexedRepresentation
      @types ||=
        if types.is_a?(String) && File.exist?(types)
          WCC::Contentful::ContentTypeIndexer.load(types).types
        end

      unless @types
        raise ArgumentError, 'Cannot parse types - not an IndexedRepresentation ' \
          "nor a schema file on disk: #{types}"
      end

      @store = store
      @root_module = WCC::Contentful::Graphql::Types
    end

    def configure(&block)
      ensure_schema_types

      instance_exec(&block)
      self
    end

    def build_schema
      ensure_schema_types
      root_query_type = build_root_query

      builder = self
      frozen_schema_types = schema_types.dup.freeze
      closed_store = @store
      Class.new(base_schema) do
        query root_query_type

        define_singleton_method(:resolve_type) do |_type, obj, _ctx|
          content_type = WCC::Contentful::Helpers.content_type_from_raw(obj)
          frozen_schema_types[content_type]
        end

        define_singleton_method(:object_from_id) do |node_id, _ctx|
          closed_store.find(node_id)
        end

        define_singleton_method(:id_from_object) do |object, _type, _ctx|
          object.try(:id) || object.dig('id') || object.dig('sys', 'id')
        end
      end
    end

    private

    def build_root_query
      closed_store = @store
      closed_schema_types = schema_types
      closed_root_types = root_types
      root_module.const_set('ContentfulGraphQLQuery',
        Class.new(base_object) do
          extend WCC::Contentful::Graphql::Resolvers
          extend WCC::Contentful::Graphql::FieldHelper

          description 'The query root of this schema'

          closed_root_types.each do |content_type|
            schema_type = closed_schema_types[content_type]

            field schema_type.name.to_sym, schema_type,
              null: false, resolver: root_field_single_resolver(content_type, schema_type)

            field "all#{schema_type.name}".to_sym, schema_type.to_list_type,
              null: false, resolver: root_field_all_resolver(content_type, schema_type)
          end
        end)
    end

    def ensure_schema_types
      @types.each_with_object({}) do |(k, v), h|
        h[k] ||= build_schema_type(v)
      end
    end

    def build_schema_type(typedef)
      const = typedef.name
      return @root_module.const_get(const) if @root_module.const_defined?(const)

      typedef = typedef.deep_dup.freeze
      store = @store
      builder = self
      content_type = typedef.content_type
      # do this in two steps - set first, then eval fields.  This lets us have circular
      # references.  If another class's definition refers back to me, i'm already
      # set so we bail above in the return.
      root_module.const_set(const, Class.new(base_object) do
        extend WCC::Contentful::Graphql::Resolvers
        extend WCC::Contentful::Graphql::FieldHelper

        description("Generated from content type #{content_type}")

        field :id, String,
          null: false, resolver: WCC::Contentful::Graphql::Resolvers::IDResolver

        field :_content_type, String,
          null: false, resolver: content_type_resolver(content_type)
      end)

      root_module.const_get(const).class_eval do
        # Make a field for each column:
        typedef.fields.each_value do |f|
          case f.type
          when :Asset
            type = builder.schema_types['Asset']
            type = type.to_list_type if f.array
            field(f.name.to_sym, type,
              null: true,
              resolver: link_resolver(f.name, store: store))
          when :Link
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
            field(f.name.to_sym, type,
              null: true,
              resolver: link_resolver(f.name, store: store))
          else
            contentful_field(f.name, f.type, array: f.array)
          end
        end
      end
    end

    def _get_or_create(const_name)
      if root_module.const_defined?(const_name)
        root_module.const_get(const_name)
      else
        root_module.const_set(const_name, yield)
      end
    end
  end
end

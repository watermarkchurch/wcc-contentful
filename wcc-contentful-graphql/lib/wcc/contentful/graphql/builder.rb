# frozen_string_literal: true

require 'graphql'

require_relative 'types'
require_relative 'resolvers'
require_relative 'field_helper'

GraphQL::Define::DefinedObjectProxy.__send__(:include, WCC::Contentful::Graphql::FieldHelper)

module WCC::Contentful::Graphql
  class Builder
    def root_module(new_module = nil)
      return @root_module unless new_module

      @root_module = new_module
      @schema_types = nil
      @root_types = nil
      @base_field = nil
      @base_object = nil
      @base_interface = nil
      @base_schema = nil
    end

    def base_field(new_base_field = nil)
      return @base_field = new_base_field if new_base_field

      @base_field ||= _get_or_create('BaseField') { Class.new(GraphQL::Schema::Field) }
    end

    def base_object(new_base_object = nil)
      return @base_object = new_base_object if new_base_object

      field = base_field
      @base_object ||=
        _get_or_create('BaseObject') do
          Class.new(GraphQL::Schema::Object) do
            field_class field
          end
        end
    end

    def base_interface(new_base_interface = nil)
      return @base_interface = new_base_field if new_base_interface

      field = base_field
      @base_interface ||=
        _get_or_create('BaseInterface') do
          Module.new do
            include GraphQL::Schema::Interface
            field_class field
          end
        end
    end

    def base_schema(new_base_schema = nil)
      return @base_schema = new_base_schema if new_base_schema

      @base_schema ||= _get_or_create('BaseSchema') { Class.new(GraphQL::Schema) }
    end

    # A hash of content-type => Ruby class extending from base_object in the schema
    def schema_types
      @schema_types ||=
        @types.each_with_object({}) do |(k, v), h|
          h[k] = _get_or_create(v.name) { Class.new(base_object) }
        end
    end

    # The content types which will become fields on the root query object
    def root_types
      @root_types ||= @types.keys
    end

    # Union types and
    def extra_types
      @extra_types ||= {}
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
      instance_exec(&block)
      self
    end

    def build_schema(klass = nil, query_type: nil)
      schema_types.each do |(k, v)|
        build_schema_type(@types[k], v)
      end

      builder = self
      frozen_schema_types = schema_types.dup.freeze
      closed_store = @store
      klass ||= _get_or_create('Schema') { Class.new(base_schema) }
      klass.class_eval do
        query(builder.build_root_query(query_type))

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
      klass
    end

    def build_root_query(klass = nil)
      closed_schema_types = schema_types
      closed_root_types = root_types
      closed_store = @store
      klass ||= _get_or_create('Query') { Class.new(base_object) }
      klass.class_eval do
        extend WCC::Contentful::Graphql::Resolvers
        extend WCC::Contentful::Graphql::FieldHelper

        description 'The query root of this schema'

        closed_root_types.each do |content_type|
          schema_type = closed_schema_types[content_type]
          field schema_type.name.demodulize, schema_type,
            null: true, resolver: root_field_single_resolver(content_type, schema_type,
              store: closed_store)

          field "all#{schema_type.name.demodulize}", [schema_type],
            null: true, resolver: root_field_all_resolver(content_type, schema_type,
              store: closed_store)
        end
      end
      klass
    end

    def build_union_type(from_types, name)
      if arr = from_types.find { |t| t.is_a? Array }
        raise ArgumentError, "array within array - #{arr.inspect}"
      end

      _get_or_create(name) do
        Class.new(GraphQL::Schema::Union) do
          possible_types(*from_types)
        end
      end
    end

    private

    def build_schema_type(typedef, klass)
      typedef = typedef.deep_dup.freeze
      store = @store
      builder = self
      content_type = typedef.content_type
      # do this in two steps - set first, then eval fields.  This lets us have circular
      # references.  If another class's definition refers back to me, i'm already
      # set so we bail above in the return.
      klass.class_eval do
        extend WCC::Contentful::Graphql::Resolvers
        extend WCC::Contentful::Graphql::FieldHelper

        description("Generated from content type #{content_type}")

        field :id, GraphQL::Types::ID,
          null: false, resolver: WCC::Contentful::Graphql::Resolvers::IDResolver

        field '_content_type', String,
          null: false, camelize: false, resolver: content_type_resolver(content_type)

        # Make a field for each column:
        typedef.fields.each_value do |f|
          case f.type
          when :Asset
            type = builder.schema_types['Asset']
            type = [type] if f.array
            field(f.name.to_sym, type,
              null: true,
              resolver: link_resolver(f.name, store: store))
          when :Link
            type =
              if f.link_types.nil? || f.link_types.empty?
                builder.extra_types['AnyContentful'] ||=
                  builder.build_union_type(builder.schema_types.values, 'AnyContentful')
              elsif f.link_types.length == 1
                result = builder.schema_types[f.link_types.first]
                result
              else
                from_types = builder.schema_types.select { |(key, _)| f.link_types.include?(key) }
                name = "#{typedef.name}_#{f.name}"
                builder.extra_types[name] ||= builder.build_union_type(from_types.values, name)
              end
            # null: true allows nil elements in the array
            # https://github.com/rmosolgo/graphql-ruby/issues/2169#issuecomment-470268252
            type = [type, null: true] if f.array

            field(f.name.to_sym, type,
              null: true,
              resolver: link_resolver(f.name, store: store))
          else
            contentful_field(f.name, f.type, array: f.array)
          end
        end
      end
      klass
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

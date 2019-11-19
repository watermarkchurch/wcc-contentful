# frozen_string_literal: true

module WCC::Contentful::Graphql::Resolvers
  extend self

  def content_type_resolver(content_type)
    Class.new(GraphQL::Schema::Resolver) do
      define_method(:resolve) { content_type }
    end
  end

  def link_resolver(field_name, store:)
    Class.new(GraphQL::Schema::Resolver) do
      define_method(:resolve) do
        links =
          if object.key?(field_name)
            object[field_name]
          else
            object.dig('fields', field_name)
          end
        return if links.nil?

        locale = ctx[:locale] || 'en-US'
        links = links[locale] if links.key?(locale)

        if links.is_a? Array
          links.reject(&:nil?).map { |l| find(l) }
        else
          find(links)
        end
      end

      define_method(:find) do
        return link unless id = link.try(:dig, 'sys', 'id')

        store.find(id)
      end
    end
  end

  def field_resolver(field_name)
    field_name = field_name.to_s

    Class.new(GraphQL::Schema::Resolver) do
      define_method(:resolve) do
        next obj.map { |o| resolver.call(o, args, ctx) } if obj.is_a? Array

        result =
          if obj.key?(field_name)
            obj.dig(field_name)
          else
            obj.dig('fields', field_name)
          end
        locale = ctx[:locale] || 'en-US'
        result = result[locale] if result.try(:key?, locale)
        result
      end
    end
  end

  def root_field_single_resolver(content_type, schema_type)
    Class.new(GraphQL::Schema::Resolver) do
      argument :id, String, required: false

      schema_type.fields.each do |(name, field)|
        next unless input_type = WCC::Contentful::Graphql::Types::QueryOperatorInput.call(field.type)

        argument name, input_type, required: false
      end

      define_method(:resolve) do |**args|
        if args['id'].nil?
          closed_store.find_by(content_type: content_type, filter: args.to_h)
        else
          closed_store.find(args['id'])
        end
      end
    end
  end

  def root_field_all_resolver(content_type, schema_type)
    Class.new(GraphQL::Schema::Resolver) do
      unless schema_type.fields.empty?
        argument :filter, WCC::Contentful::Graphql::Types::FilterInputType.call(schema_type),
          required: false
      end

      define_method(:resolve) do |**args|
        relation = store.find_all(content_type: content_type)
        relation = relation.apply(args[:filter].to_h, ctx) if args[:filter]
        relation.to_enum
      end
    end
  end

  class IDResolver < GraphQL::Schema::Resolver
    def resolve
      return obj['id'] if obj.key?('id')

      obj.dig('sys', 'id')
    end
  end
end

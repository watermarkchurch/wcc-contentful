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

        locale = context[:locale] || 'en-US'
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
      define_method(:resolve) do |**args|
        next object.map { |o| new(object: o, context: context).resolve(**args) } if object.is_a? Array

        result =
          if object.key?(field_name)
            object.dig(field_name)
          else
            object.dig('fields', field_name)
          end
        locale = context[:locale] || 'en-US'
        result = result[locale] if result.try(:key?, locale)
        result
      end
    end
  end

  def root_field_single_resolver(content_type, schema_type, store:)
    Class.new(GraphQL::Schema::Resolver) do
      argument :id, String, required: false

      schema_type.fields.each do |(name, field)|
        next unless input_type = WCC::Contentful::Graphql::Types::QueryOperatorInput.call(field.type)

        argument name, input_type, required: false
      end

      define_method(:resolve) do |**args|
        if args['id'].nil?
          store.find_by(content_type: content_type, filter: args.to_h)
        else
          store.find(args['id'])
        end
      end
    end
  end

  def root_field_all_resolver(content_type, schema_type, store:)
    Class.new(GraphQL::Schema::Resolver) do
      unless schema_type.fields.empty?
        argument :filter, WCC::Contentful::Graphql::Types::FilterInputType.call(schema_type),
          required: false
      end

      define_method(:resolve) do |**args|
        relation = store.find_all(content_type: content_type)
        relation = relation.apply(args[:filter].to_h, context) if args[:filter]
        relation.to_enum
      end
    end
  end

  class IDResolver < GraphQL::Schema::Resolver
    def resolve
      return object['id'] if object.key?('id')

      object.dig('sys', 'id')
    end
  end
end

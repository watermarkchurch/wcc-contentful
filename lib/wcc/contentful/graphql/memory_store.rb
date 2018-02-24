# frozen_string_literal: true

require 'singleton'

module WCC::Contentful::Graphql
  class MemoryStore
    include Singleton

    def initialize
      @hash = {}
      @mutex = Mutex.new
    end

    def index(key, value)
      @mutex.synchronize do
        @hash[key] = value
      end
    end

    def find(key)
      @mutex.synchronize do
        @hash[key]
      end
    end

    def find_by(content_type:)
      relation =
        @hash.each_with_object([]) do |(_k, v), a|
          value_content_type = v.dig('sys', 'contentType', 'sys', 'id')
          next if value_content_type.nil? || value_content_type != content_type
          a << v
        end
      Query.new(relation)
    end

    class Query
      attr_reader :relation
      delegate :first, to: :@relation
      delegate :map, to: :@relation

      def initialize(relation)
        @relation = relation
      end

      def apply(filter, context)
        return eq(filter[:field], filter[:eq], context) if filter[:eq]

        raise ArgumentError, "Filter not implemented: #{filter}"
      end

      def eq(field, expected, context)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'
        Query.new(@relation.select do |v|
          val = v.dig('fields', field, locale)
          if val.is_a? Array
            val.include?(expected)
          else
            val == expected
          end
        end)
      end
    end
  end
end

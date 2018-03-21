# frozen_string_literal: true

module WCC::Contentful::Store
  class MemoryStore < Base
    def initialize
      @hash = {}
      @mutex = Mutex.new
    end

    def set(key, value)
      value = value.deep_dup.freeze
      @mutex.synchronize do
        @hash[key] = value
      end
    end

    def delete(key)
      @mutex.synchronize do
        @hash.delete(key)
      end
    end

    def keys
      @mutex.synchronize { @hash.keys }
    end

    def find(key)
      @mutex.synchronize do
        @hash[key]
      end
    end

    def find_all(content_type:)
      relation = @mutex.synchronize { @hash.values }

      relation =
        relation.reject do |v|
          value_content_type = v.dig('sys', 'contentType', 'sys', 'id')
          value_content_type.nil? || value_content_type != content_type
        end
      Query.new(relation)
    end

    class Query < Base::Query
      def result
        @relation.dup
      end

      def initialize(relation)
        @relation = relation
      end

      def eq(field, expected, context = nil)
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

# frozen_string_literal: true

require_relative 'instrumentation'

module WCC::Contentful::Store
  class MemoryStore < Base
    include WCC::Contentful::Store::Instrumentation

    def initialize
      super
      @hash = {}
    end

    def set(key, value)
      value = value.deep_dup.freeze
      ensure_hash value
      mutex.with_write_lock do
        old = @hash[key]
        @hash[key] = value
        old
      end
    end

    def delete(key)
      mutex.with_write_lock do
        @hash.delete(key)
      end
    end

    def keys
      mutex.with_read_lock { @hash.keys }
    end

    def find(key, **_options)
      mutex.with_read_lock do
        @hash[key]
      end
    end

    def find_all(content_type:, options: nil)
      relation = mutex.with_read_lock { @hash.values }

      relation =
        relation.reject do |v|
          value_content_type = v.try(:dig, 'sys', 'contentType', 'sys', 'id')
          value_content_type.nil? || value_content_type != content_type
        end
      Query.new(self, content_type, relation, options)
    end

    class Query < Base::Query
      def to_enum
        return @relation.dup unless @options[:include]

        @relation.map { |e| resolve_includes(e, @options[:include]) }
      end

      def initialize(store, content_type, relation, options = nil)
        super(store, content_type)
        @relation = relation
        @options = options || {}
      end

      def apply_operator(operator, field, expected, context = nil)
        raise NotSupportedError, "operator #{operator} not yet supported" unless operator == :eq

        eq(field, expected, context)
      end

      def eq(field, expected, context = nil)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'
        Query.new(@store, content_type, @relation.select do |v|
          val = v.dig('fields', field, locale)
          if val.is_a? Array
            val.include?(expected)
          else
            val == expected
          end
        end, @options)
      end
    end
  end
end

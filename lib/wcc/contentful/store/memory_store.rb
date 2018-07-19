# frozen_string_literal: true

module WCC::Contentful::Store
  class MemoryStore < Base
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

    def find(key)
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
      Query.new(self, relation, options)
    end

    class Query < Base::Query
      def result
        return @relation.dup unless @options[:include]
        @relation.map { |e| resolve_includes(e, @options[:include]) }
      end

      def initialize(store, relation, options = nil)
        super(store)
        @relation = relation
        @options = options || {}
      end

      def eq(field, expected, context = nil)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'
        Query.new(@store, @relation.select do |v|
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

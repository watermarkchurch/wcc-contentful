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

    def execute(query)
      relation = mutex.with_read_lock { @hash.values }

      relation =
        relation.reject do |v|
          value_content_type = v.try(:dig, 'sys', 'contentType', 'sys', 'id')
          if query.content_type == 'Asset'
            !value_content_type.nil?
          else
            value_content_type != query.content_type
          end
        end

      query.conditions.reduce(relation) do |memo, condition|
        memo.select do |entry|
          val = entry.dig(*condition.path)

          if val.is_a? Array
            val.include?(condition.expected)
          else
            val == condition.expected
          end
        end
      end
    end

    class Query < WCC::Contentful::Store::Query
      # we don't support these
      WCC::Contentful::Store::Query::OPERATORS.each do |op|
        undef_method op unless op == :eq
      end
    end
  end
end

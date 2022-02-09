# frozen_string_literal: true

require_relative 'instrumentation'

module WCC::Contentful::Store
  # The MemoryStore is the most naiive store implementation and a good reference
  # point for more useful implementations.  It only implements equality queries
  # and does not support querying through an association.
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

    def find(key, **_options)
      mutex.with_read_lock do
        @hash[key]
      end
    end

    def execute(query)
      query.conditions.each do |condition|
        # Our naiive implementation only supports equality operator
        raise ArgumentError, "Operator :#{condition.op} not supported" unless condition.op == :eq
      end

      relation = mutex.with_read_lock { @hash.values }

      # relation is an enumerable that we apply conditions to in the form of
      #  Enumerable#select and Enumerable#reject.
      relation =
        relation.lazy.reject do |v|
          value_content_type = v.try(:dig, 'sys', 'contentType', 'sys', 'id')
          if query.content_type == 'Asset'
            !value_content_type.nil?
          else
            value_content_type != query.content_type
          end
        end

      # For each condition, we apply a new Enumerable#select with a block that
      # enforces the condition.
      query.conditions.reduce(relation) do |memo, condition|
        memo.select do |entry|
          # The condition's path tells us where to find the value in the JSON object
          val = entry.dig(*condition.path)

          # For arrays, equality is defined as does the array include the expected value.
          # See https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/search-parameters/array-equality-inequality
          if val.is_a? Array
            val.include?(condition.expected)
          else
            val == condition.expected
          end
        end
      end
    end
  end
end

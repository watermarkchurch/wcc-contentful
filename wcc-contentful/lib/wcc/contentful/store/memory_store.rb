# frozen_string_literal: true

require_relative 'instrumentation'

module WCC::Contentful::Store
  # The MemoryStore is the most naiive store implementation and a good reference
  # point for more useful implementations.  It only implements equality queries
  # and does not support querying through an association.
  class MemoryStore < Base
    delegate :locale_fallbacks, to: :@configuration

    def initialize(configuration = nil)
      super

      @configuration = configuration
      @mutex = Concurrent::ReentrantReadWriteLock.new
      @hash = {}
    end

    def set(key, value)
      value = value.deep_dup.freeze
      ensure_hash value
      @mutex.with_write_lock do
        old = @hash[key]
        @hash[key] = value
        old
      end
    end

    def delete(key)
      @mutex.with_write_lock do
        @hash.delete(key)
      end
    end

    def keys
      @mutex.with_read_lock { @hash.keys }
    end

    def find(key, **_options)
      @mutex.with_read_lock do
        @hash[key]
      end
    end

    SUPPORTED_OPS = %i[eq ne in nin].freeze

    def execute(query)
      if bad_op = (query.conditions.map(&:op) - SUPPORTED_OPS).first
        raise ArgumentError, "Operator :#{bad_op} not supported"
      end

      # Since @hash.values returns a new array, we only need to lock here
      relation = @mutex.with_read_lock { @hash.values }

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
        __send__("apply_#{condition.op}", memo, condition)
      end
    end

    private

    def apply_eq(memo, condition)
      memo.select { |entry| eq?(entry, condition) }
    end

    def apply_ne(memo, condition)
      memo.reject { |entry| eq?(entry, condition) }
    end

    def eq?(entry, condition)
      val = select_value_for_compare(entry, condition)

      # For arrays, equality is defined as does the array include the expected value.
      # See https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/search-parameters/array-equality-inequality
      if val.is_a? Array
        val.include?(condition.expected)
      else
        val == condition.expected
      end
    end

    def apply_in(memo, condition)
      memo.select { |entry| in?(entry, condition) }
    end

    def apply_nin(memo, condition)
      memo.reject { |entry| in?(entry, condition) }
    end

    def in?(entry, condition)
      val = select_value_for_compare(entry, condition)

      if val.is_a? Array
        # TODO: detect if in ruby 3.1 and use val.intersect?(condition.expected)
        val.any? { |item| condition.expected.include?(item) }
      else
        condition.expected.include?(val)
      end
    end

    # Selects the value for the condition from the entry, taking into account locale fallbacks
    def select_value_for_compare(entry, condition)
      condition.each_locale_fallback do |cond|
        # The condition's path tells us where to find the value in the JSON object
        val = entry.dig(*cond.path)

        # If the object has no value for this locale, try the fallbacks
        next if val.nil?

        # The object has a value for this locale, so we must compare against it and not the fallbacks
        return val
      end
    end
  end
end

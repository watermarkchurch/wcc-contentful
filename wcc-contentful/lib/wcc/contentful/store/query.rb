# frozen_string_literal: true

module WCC::Contentful::Store
  # The base class for query objects returned by find_all.  Subclasses should
  # override the #result method to return an array-like containing the query
  # results.
  class Query
    delegate :first,
      :map,
      :flat_map,
      :count,
      :select,
      :reject,
      :take,
      :take_while,
      :drop,
      :drop_while,
      :zip,
      :to_a,
      to: :to_enum

    OPERATORS = %i[
      eq
      ne
      all
      in
      nin
      exists
      lt
      lte
      gt
      gte
      query
      match
    ].freeze

    # @abstract Subclasses should provide this in order to fetch the results
    #   of the query.
    def to_enum
      raise NotImplementedError
    end

    def initialize(store)
      @store = store
    end

    # @abstract Subclasses can either override this method to properly respond
    #   to find_by query objects, or they can define a method for each supported
    #   operator.  Ex. `#eq`, `#ne`, `#gt`.
    def apply_operator(operator, field, expected, context = nil)
      respond_to?(operator) ||
        raise(ArgumentError, "Operator not implemented: #{operator}")

      public_send(operator, field, expected, context)
    end

    # Called with a filter object by {Base#find_by} in order to apply the filter.
    def apply(filter, context = nil)
      filter = normalize_dot_notation_to_hash(filter)
      filter.reduce(self) do |query, (field, value)|
        query._apply(field, value, context)
      end
    end

    protected

    def _apply(field, value, context)
      if value.is_a?(Hash)
        if op?(k = value.keys.first)
          apply_operator(k.to_sym, field.to_s, value[k], context)
        else
          nested_conditions(field, value, context)
        end
      else
        apply_operator(:eq, field.to_s, value)
      end
    end

    # naive implementation recursively descends the graph to turns links into
    # the actual entry data.  This calls {Base#find} for each link and so it is
    # very inefficient.
    #
    # @abstract Override this to provide a more efficient implementation for
    #   a given store.
    def resolve_includes(entry, depth)
      return entry unless entry && depth && depth > 0

      WCC::Contentful::LinkVisitor.new(entry, :Link, :Asset, depth: depth).map! do |val|
        resolve_link(val)
      end
    end

    def resolve_link(val)
      return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Link'
      return val unless included = @store.find(val.dig('sys', 'id'))

      included
    end

    def nested_conditions(field, value, context)
      if value.keys.length == 1
        k, v = value.first
        return _apply([field, k].join('.'), v, context) if k == 'id' || (k == 'sys' && v == 'id')
      end

      self_join(field, value, context)
    end

    def self_join(_join_on, _conditions, _context)
      raise NotImplementedError, 'This store does not support the :nested_queries feature'
    end

    private

    def normalize_dot_notation_to_hash(hash, depth = 0)
      raise ArgumentError, 'Query is too complex (depth > 7)' if depth > 7

      hash.each_with_object({}) do |(k, v), h|
        k = k.to_s
        if k.include?('.')
          k, *rest = k.split('.')
          v = { rest.join('.') => v }
        end
        v = normalize_dot_notation_to_hash(v, depth + 1) if v.is_a? Hash
        h[k] = v
      end
    end

    def op?(key)
      OPERATORS.include?(key.to_sym)
    end

    def sys?(field)
      field.to_s =~ /sys\./
    end

    def id?(field)
      field.to_sym == :id
    end
  end
end

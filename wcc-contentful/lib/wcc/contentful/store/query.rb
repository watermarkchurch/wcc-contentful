# frozen_string_literal: true

require_relative '../../contentful'

module WCC::Contentful::Store
  # The default query object returned by Stores that extend WCC::Contentful::Store::Base.
  # It exposes several chainable query methods to apply query filters.
  # Enumerating the query executes it, caching the result.
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

    # Executes the query against the store and memoizes the resulting enumerable.
    #  Subclasses can override this to provide a more efficient implementation.
    def to_enum
      @to_enum ||=
        begin
          result_set = store.execute(self).lazy
          if @options[:include] && @options[:include] > 0
            result_set =
              result_set.map do |entry|
                resolve_includes(entry, @options[:include])
              end
          end
          result_set
        end
    end

    attr_reader :store, :content_type, :conditions

    def initialize(store, content_type:, conditions: nil, options: nil, **extra)
      @store = store
      @content_type = content_type
      @conditions = conditions || []
      @options = options || {}
      @extra = extra
    end

    # Returns a new chained Query that has a new condition.  The new condition
    # represents the WHERE comparison being applied here.  The underlying store
    # implementation translates this condition statement into an appropriate
    # query against the datastore.
    #
    # @example
    #  query = query.apply_operator(:gt, :timestamp, '2019-01-01', context)
    #  # in a SQL based store, the query now contains a condition like:
    #  #  WHERE table.'timestamp' > '2019-01-01'
    #
    # @operator one of WCC::Contentful::Store::Query::OPERATORS
    # @field The path through the fields of the content type that we are querying against.
    #          Can be an array, symbol, or dotted-notation path specification.
    # @expected The expected value to compare the field's value against.
    # @context A context object optionally containing `context[:locale]`
    def apply_operator(operator, field, expected, context = nil)
      raise ArgumentError, "Operator #{operator} not supported" unless respond_to?(operator)

      field = field.to_s if field.is_a? Symbol
      path = field.is_a?(Array) ? field : field.split('.')

      path = self.class.normalize_condition_path(path, context)

      _append_condition(
        Condition.new(path, operator, expected)
      )
    end

    WCC::Contentful::Store::Query::OPERATORS.each do |op|
      # @see #apply_operator
      define_method(op) do |field, expected, context = nil|
        apply_operator(op, field, expected, context)
      end
    end

    # Called with a filter object by {Base#find_by} in order to apply the filter.
    # The filter in this case is a hash where the keys are paths and the values
    # are expectations.
    # @see #apply_operator
    def apply(filter, context = nil)
      self.class.flatten_filter_hash(filter).reduce(self) do |query, cond|
        query.apply_operator(cond[:op], cond[:path], cond[:expected], context)
      end
    end

    protected

    def _append_condition(condition)
      self.class.new(
        store,
        content_type: content_type,
        conditions: conditions + [condition],
        options: @options,
        **@extra
      )
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

    class << self
      def op?(key)
        OPERATORS.include?(key.to_sym)
      end

      # Turns a hash into a flat array of individual conditions, where each
      # element can be passed as params to apply_operator
      def flatten_filter_hash(hash, path = [])
        hash.flat_map do |(k, v)|
          k = k.to_s
          if k.include?('.')
            k, *rest = k.split('.')
            v = { rest.join('.') => v }
          end

          if v.is_a? Hash
            flatten_filter_hash(v, path + [k])
          elsif op?(k)
            { path: path, op: k.to_sym, expected: v }
          else
            { path: path + [k], op: :eq, expected: v }
          end
        end
      end

      def known_locales
        @known_locales = WCC::Contentful.locales.keys
      end
      RESERVED_NAMES = %w[fields sys].freeze

      # Takes a path array in non-normal form and inserts 'sys', 'fields',
      # and the current locale as appropriate to normalize it.
      # rubocop:disable Metrics/BlockNesting
      def normalize_condition_path(path, context = nil)
        context_locale = context[:locale] if context.present?
        context_locale ||= 'en-US'

        rev_path = path.reverse
        new_path = []

        current_tuple = []
        current_locale_was_inferred = false
        until rev_path.empty? && current_tuple.empty?
          raise ArgumentError, "Query too complex: #{path.join('.')}" if new_path.length > 7

          case current_tuple.length
          when 0
            # expect a locale
            current_tuple <<
              if known_locales.include?(rev_path[0])
                current_locale_was_inferred = false
                rev_path.shift
              else
                # infer locale
                current_locale_was_inferred = true
                context_locale
              end
          when 1
            # expect a path
            current_tuple << rev_path.shift
          when 2
            # expect 'sys' or 'fields'
            current_tuple <<
              if RESERVED_NAMES.include?(rev_path[0])
                rev_path.shift
              else
                # infer 'sys' or 'fields'
                current_tuple.last == 'id' ? 'sys' : 'fields'
              end

            if current_tuple.last == 'sys' && current_locale_was_inferred
              # remove the inferred current locale
              current_tuple.shift
            end
            new_path << current_tuple
            current_tuple = []
          end
        end

        new_path.flat_map { |x| x }.reverse.freeze
      end
      # rubocop:enable Metrics/BlockNesting
    end

    Condition =
      Struct.new(:path, :op, :expected) do
        LINK_KEYS = %w[id type linkType].freeze

        def path_tuples
          @path_tuples ||=
            [].tap do |arr|
              remaining = path.dup
              until remaining.empty?
                locale = nil
                link_sys = nil
                link_field = nil

                sys_or_fields = remaining.shift
                field = remaining.shift
                locale = remaining.shift if sys_or_fields == 'fields'

                if remaining[0] == 'sys' && LINK_KEYS.include?(remaining[1])
                  link_sys = remaining.shift
                  link_field = remaining.shift
                end

                arr << [sys_or_fields, field, locale, link_sys, link_field].compact
              end
            end
        end
      end
  end
end

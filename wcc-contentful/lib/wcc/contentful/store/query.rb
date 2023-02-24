# frozen_string_literal: true

require_relative '../../contentful'
require_relative './query/interface'
require_relative './query/condition'

module WCC::Contentful::Store
  # The default query object returned by Stores that extend WCC::Contentful::Store::Base.
  # It exposes several chainable query methods to apply query filters.
  # Enumerating the query executes it, caching the result.
  class Query
    include WCC::Contentful::Store::Query::Interface
    include Enumerable

    # by default all enumerable methods delegated to the to_enum method
    delegate(*(Enumerable.instance_methods - Module.instance_methods), to: :to_enum)

    # except count, which should not iterate the lazy enumerator
    delegate :count, to: :result_set

    # Executes the query against the store and memoizes the resulting enumerable.
    #  Subclasses can override this to provide a more efficient implementation.
    def to_enum
      @to_enum ||=
        result_set.lazy.map { |row| resolve_includes(row, @options[:include]) }
    end

    attr_reader :store, :content_type, :conditions

    def initialize(store, content_type:, conditions: nil, options: nil, configuration: nil, **extra) # rubocop:disable Metrics/ParameterLists
      @store = store
      @content_type = content_type
      @conditions = conditions || []
      @options = options || {}
      @configuration = configuration || WCC::Contentful.configuration
      @extra = extra
    end

    FALSE_VALUES = [
      false, 0,
      '0', :'0',
      'f', :f,
      'F', :F,
      'false', :false, # rubocop:disable Lint/BooleanSymbol
      'FALSE', :FALSE,
      'off', :off,
      'OFF', :OFF
    ].to_set.freeze

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
    # @operator one of WCC::Contentful::Store::Query::Interface::OPERATORS
    # @field The path through the fields of the content type that we are querying against.
    #          Can be an array, symbol, or dotted-notation path specification.
    # @expected The expected value to compare the field's value against.
    # @context A context object optionally containing `context[:locale]`
    def apply_operator(operator, field, expected, _context = nil)
      operator ||= expected.is_a?(Array) ? :in : :eq
      raise ArgumentError, "Operator #{operator} not supported" unless respond_to?(operator)
      raise ArgumentError, 'value cannot be nil (try using exists: false)' if expected.nil?

      case operator
      when :in, :nin, :all
        expected = Array(expected)
      when :exists
        expected = !FALSE_VALUES.include?(expected)
      end

      field = field.to_s if field.is_a? Symbol
      path = field.is_a?(Array) ? field : field.split('.')

      path = self.class.normalize_condition_path(path, @options)

      _append_condition(
        Condition.new(path, operator, expected, @configuration&.locale_fallbacks || {})
      )
    end

    WCC::Contentful::Store::Query::Interface::OPERATORS.each do |op|
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

    # Override this to provide a result set from the Query object itself
    # rather than from calling #execute in the store.
    def result_set
      @result_set ||= store.execute(self)
    end

    private

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
    # the actual entry data.  If the result set from #execute returns a tuple,
    # it tries to pull links from the second column in the tuple.  This allows
    # a store implementation to return ex. `SELECT entry, includes FROM...`
    # Otherwise, if the store does not return a tuple or does not have an includes
    # column, it calls {Base#find} for each link and so it is very inefficient.
    def resolve_includes(row, depth)
      entry = row.try(:entry) || row.try(:[], 0) || row
      includes = row.try(:includes) || row.try(:[], 1)
      return entry unless entry && depth && depth > 0

      WCC::Contentful::LinkVisitor.new(entry, :Link,
        # Walk all the links except for the leaf nodes
        depth: depth - 1).map! do |val|
        resolve_link(val, includes)
      end
    end

    # Returns the resolved link if it exists in the includes hash, or returns
    # the link hash.
    def resolve_link(val, includes)
      return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Link'

      id = val.dig('sys', 'id')
      included =
        if includes
          includes[id]
        else
          @store.find(id)
        end

      included || val
    end

    class << self
      def op?(key)
        Interface::OPERATORS.include?(key.to_sym)
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
            { path: path + [k], op: nil, expected: v }
          end
        end
      end

      def known_locales
        @known_locales ||= WCC::Contentful.locales&.keys || ['en-US']
      end
      RESERVED_NAMES = %w[fields sys].freeze

      # Takes a path array in non-normal form and inserts 'sys', 'fields',
      # and the current locale as appropriate to normalize it.
      # rubocop:disable Metrics/BlockNesting
      def normalize_condition_path(path, options = nil)
        context_locale = options[:locale] if options.present?
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
  end
end

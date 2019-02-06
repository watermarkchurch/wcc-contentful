# frozen_string_literal: true

# @api Store
module WCC::Contentful::Store
  # This is the base class for stores which implement #index, and therefore
  # must be kept up-to-date via the Sync API.
  # @abstract At a minimum subclasses should override {#find}, {#find_all}, {#set},
  #   and #{delete}. As an alternative to overriding set and delete, the subclass
  #   can override {#index}.  Index is called when a webhook triggers a sync, to
  #   update the store.
  class Base
    # Finds an entry by it's ID.  The returned entry is a JSON hash
    # @abstract Subclasses should implement this at a minimum to provide data
    #   to the WCC::Contentful::Model API.
    def find(_id)
      raise NotImplementedError, "#{self.class} does not implement #find"
    end

    # Sets the value of the entry with the given ID in the store.
    # @abstract
    def set(_id, _value)
      raise NotImplementedError, "#{self.class} does not implement #set"
    end

    # Removes the entry by ID from the store.
    # @abstract
    def delete(_id)
      raise NotImplementedError, "#{self.class} does not implement #delete"
    end

    # Processes a data point received via the Sync API.  This can be a published
    # entry or asset, or a 'DeletedEntry' or 'DeletedAsset'.  The default
    # implementation calls into #set and #delete to perform the appropriate
    # operations in the store.
    def index(json)
      # Subclasses can override to do this in a more performant thread-safe way.
      # Example: postgres_store could do this in a stored procedure for speed
      mutex.with_write_lock do
        prev =
          case type = json.dig('sys', 'type')
          when 'DeletedEntry', 'DeletedAsset'
            delete(json.dig('sys', 'id'))
          else
            set(json.dig('sys', 'id'), json)
          end

        if (prev_rev = prev&.dig('sys', 'revision')) && (next_rev = json.dig('sys', 'revision'))
          if next_rev < prev_rev
            # Uh oh! we overwrote an entry with a prior revision.  Put the previous back.
            return index(prev)
          end
        end

        case type
        when 'DeletedEntry', 'DeletedAsset'
          nil
        else
          json
        end
      end
    end

    # Finds the first entry matching the given filter.  A content type is required.
    #
    # @param [String] content_type The ID of the content type to search for.
    # @param [Hash] filter A set of key-value pairs defining filter operations.
    #  See WCC::Contentful::Store::Base::Query
    # @param [Hash] options An optional set of additional parameters to the query
    #  defining for example include depth.  Not all store implementations respect all options.
    def find_by(content_type:, filter: nil, options: nil)
      # default implementation - can be overridden
      q = find_all(content_type: content_type, options: { limit: 1 }.merge!(options || {}))
      q = q.apply(filter) if filter
      q.first
    end

    # Finds all entries of the given content type.  A content type is required.
    #
    # @abstract Subclasses should implement this at a minimum to provide data
    #   to the {WCC::Contentful::Model} API.
    # @param [String] content_type The ID of the content type to search for.
    # @param [Hash] options An optional set of additional parameters to the query
    #  defining for example include depth.  Not all store implementations respect all options.
    # @return [Query] A query object that exposes methods to apply filters
    # rubocop:disable Lint/UnusedMethodArgument
    def find_all(content_type:, options: nil)
      raise NotImplementedError, "#{self.class} does not implement find_all"
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def initialize
      @mutex = Concurrent::ReentrantReadWriteLock.new
    end

    def ensure_hash(val)
      raise ArgumentError, 'Value must be a Hash' unless val.is_a?(Hash)
    end

    protected

    attr_reader :mutex

    # The base class for query objects returned by find_all.  Subclasses should
    # override the #result method to return an array-like containing the query
    # results.
    class Query
      delegate :first, to: :result
      delegate :map, to: :result
      delegate :count, to: :result

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
      def result
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
        filter.reduce(self) do |query, (field, value)|
          if value.is_a?(Hash)
            if op?(k = value.keys.first)
              query.apply_operator(k.to_sym, field.to_s, value[k], context)
            else
              query.nested_conditions(field, value, context)
            end
          else
            query.apply_operator(:eq, field.to_s, value)
          end
        end
      end

      protected

      # naive implementation recursively descends the graph to turns links into
      # the actual entry data.  This calls {Base#find} for each link and so it is
      # very inefficient.
      #
      # @abstract Override this to provide a more efficient implementation for
      #   a given store.
      def resolve_includes(entry, depth)
        return entry unless entry && depth && depth > 0

        WCC::Contentful::LinkVisitor.new(entry, :Link, :Asset, depth: depth).map do |val|
          resolve_link(val)
        end
      end

      def resolve_link(val)
        return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Link'
        return val unless included = @store.find(val.dig('sys', 'id'))

        included
      end

      private

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
end

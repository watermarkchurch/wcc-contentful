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

    # Returns true if this store can index values coming back from the sync API.
    def index?
      true
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
  end
end

require_relative './query'

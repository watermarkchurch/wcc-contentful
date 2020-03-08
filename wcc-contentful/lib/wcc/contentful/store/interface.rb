# frozen_string_literal: true

module WCC::Contentful::Store
  # This module represents the common interface of all Store implementations.
  # It is documentation ONLY and does not add functionality.
  #
  # This is distinct from WCC::Contentful::Store::Base, because certain helpers
  # exposed publicly by that abstract class are not part of the actual interface
  # and can change without a major version update.
  # rubocop:disable Lint/UnusedMethodArgument
  module Interface
    # TODO: legit implement Sorbet typechecks
    # https://github.com/watermarkchurch/wcc-contentful/pull/183

    # extend T::Sig
    # extend T::Helpers
    # interface!

    # Returns true if this store can persist entries and assets which are
    # retrieved from the sync API.
    # sig {abstract.returns(T::Boolean)}
    def index?
      raise NotImplementedError, "#{self.class} does not implement #index?"
    end

    # Processes a data point received via the Sync API.  This can be a published
    # entry or asset, or a 'DeletedEntry' or 'DeletedAsset'.  The default
    # implementation calls into #set and #delete to perform the appropriate
    # operations in the store.
    # sig {abstract.params(json: T.any(Entry, Asset, DeletedEntry, DeletedAsset))
    #    .returns(T.any(Entry, Asset, nil))}
    def index(_json)
      raise NotImplementedError, "#{self.class} does not implement #index"
    end

    # Finds an entry by it's ID.  The returned entry is a JSON hash
    # @abstract Subclasses should implement this at a minimum to provide data
    #   to the WCC::Contentful::Model API.
    # sig {abstract.params(id: String).returns(T.any(Entry, Asset))}
    def find(_id)
      raise NotImplementedError, "#{self.class} does not implement #find"
    end

    # Finds the first entry matching the given filter.  A content type is required.
    #
    # @param [String] content_type The ID of the content type to search for.
    # @param [Hash] filter A set of key-value pairs defining filter operations.
    #  See WCC::Contentful::Store::Base::Query
    # @param [Hash] options An optional set of additional parameters to the query
    #  defining for example include depth.  Not all store implementations respect all options.
    # sig {abstract.params(
    #   content_type: String,
    #   filter: T.nilable(T::Hash[T.any(Symbol, String), T.untyped]),
    #   options: T.nilable(T::Hash[T.any(Symbol), T.untyped]),
    # ).returns(T.any(Entry, Asset))}
    def find_by(content_type:, filter: nil, options: nil)
      raise NotImplementedError, "#{self.class} does not implement #find_by"
    end

    # Finds all entries of the given content type.  A content type is required.
    #
    # Subclasses may override this to provide their own query implementation,
    #  or else override #execute to run the query after it has been parsed.
    #
    # @param [String] content_type The ID of the content type to search for.
    # @param [Hash] options An optional set of additional parameters to the query
    #  defining for example include depth.  Not all store implementations respect all options.
    # @return [Query] A query object that exposes methods to apply filters.
    #  @see WCC::Contentful::Store::Query::Interface
    # sig {abstract.params(
    #   content_type: String,
    #   filter: T.nilable(T::Hash[T.any(Symbol, String), T.untyped]),
    #   options: T.nilable(T::Hash[T.any(Symbol), T.untyped]),
    # ).returns(WCC::Contentful::Store::Query::Interface)}
    def find_all(content_type:, options: nil)
      raise NotImplementedError, "#{self.class} does not implement #find_all"
    end

    INTERFACE_METHODS = WCC::Contentful::Store::Interface.instance_methods - Module.instance_methods
  end
  # rubocop:enable Lint/UnusedMethodArgument
end

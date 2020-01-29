# frozen_string_literal: true

class WCC::Contentful::Store::Query
  # This module represents the common interface of queries that must be returned
  # by a store's #find_all implementation.
  # It is documentation ONLY and does not add functionality.
  #
  # This is distinct from WCC::Contentful::Store::Query, because certain helpers
  # exposed publicly by that abstract class are not part of the actual interface
  # and can change without a major version update.
  module Interface
    include Enumerable

    # The set of operators that can be applied to a query.  Not all stores
    # implement all operators.  At a bare minimum a store must implement #eq.
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

    WCC::Contentful::Store::Query::Interface::OPERATORS.each do |op|
      # @see #apply_operator
      define_method(op) do |_field, _expected, _context = nil|
        raise NotImplementedError, "#{self.class} does not implement ##{op}"
      end
    end

    # Applies an equality condition to the query.  The underlying store
    # translates this into a '==' check.
    #
    # sig {abstract.params(
    #    field: T.any(T::String),
    #    expected: T.untyped,
    #    context: T.nilable(T::Hash[T.untyped, T.untyped])
    #  ).returns(T.self_type)}
    def eq(_field, _expected, _context = nil)
      raise NotImplementedError, "#{self.class} does not implement #eq"
    end

    # Called with a filter object in order to apply the filter.
    # The filter in this case is a hash where the keys are paths and the values
    # are expectations.
    #
    # sig {abstract.params(
    #    field: T.any(T::String),
    #    expected: T.untyped,
    #    context: T.nilable(T::Hash[T.untyped, T.untyped])
    #  ).returns(T.self_type)}
    def apply(_filter, _context = nil)
      raise NotImplementedError, "#{self.class} does not implement #apply"
    end
  end
end

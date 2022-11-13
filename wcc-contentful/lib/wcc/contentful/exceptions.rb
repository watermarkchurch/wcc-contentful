# frozen_string_literal: true

module WCC::Contentful
  class SyncError < StandardError
  end

  # Raised when a constant under {WCC::Contentful::Model} does not match to a
  # content type in the configured Contentful space
  class ContentTypeNotFoundError < NameError
  end

  # Raised when an entry contains a circular reference and cannot be represented
  # as a flat tree.
  class CircularReferenceError < StandardError
    attr_reader :stack, :id

    def initialize(stack, id)
      @id = id
      @stack = stack.slice(stack.index(id)..stack.length)
      super('Circular reference detected!')
    end

    def message
      return super unless stack

      super + "\n  " \
              "#{stack.last} points to #{id} which is also it's ancestor\n  " +
        stack.join('->')
    end
  end

  # Raised by {WCC::Contentful::ModelMethods#resolve Model#resolve} when attempting
  # to resolve an entry's links and that entry cannot be found in the space.
  class ResolveError < StandardError
  end

  class InitializationError < StandardError
  end

  # Raised by {WCC::Contentful::Middleware::Store::LocaleMiddleware} when the
  # backing store loads an entry for the wrong locale.
  class LocaleMismatchError < StandardError
  end
end

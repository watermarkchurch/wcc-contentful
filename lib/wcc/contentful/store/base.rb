
# frozen_string_literal: true

module WCC::Contentful::Store
  class Base
    def get(_id)
      raise NotImplementedError
    end

    def set(_id, _value)
      raise NotImplementedError
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def find_all(content_type:)
      raise NotImplementedError
    end

    def find_by(content_type:, **_filter)
      raise NotImplementedError
    end
    # rubocop:enable Lint/UnusedMethodArgument
  end
end

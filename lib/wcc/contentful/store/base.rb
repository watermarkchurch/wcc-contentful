
# frozen_string_literal: true

module WCC::Contentful::Store
  class Base
    def find(_id)
      raise NotImplementedError
    end

    def set(_id, _value)
      raise NotImplementedError
    end

    def delete(_id)
      raise NotImplementedError
    end

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

    def find_by(content_type:, filter: nil)
      # default implementation - can be overridden
      q = find_all(content_type: content_type)
      q = q.apply(filter) if filter
      q.first
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def find_all(content_type:)
      raise NotImplementedError
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def initialize
      @mutex = Concurrent::ReentrantReadWriteLock.new
    end

    protected

    attr_reader :mutex

    class Query
      delegate :first, to: :result
      delegate :map, to: :result
      delegate :count, to: :result

      def result
        raise NotImplementedError
      end

      def apply(filter, context = nil)
        filter.reduce(self) do |query, (field, value)|
          if value.is_a?(Hash)
            k = value.keys.first
            raise ArgumentError, "Filter not implemented: #{value}" unless query.respond_to?(k)
            query.public_send(k, field, value[k], context)
          else
            query.eq(field.to_s, value)
          end
        end
      end
    end
  end
end

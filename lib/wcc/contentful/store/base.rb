
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

    def index(id, sync_value)
      # TODO: implement all of sync
      set(id, sync_value)
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

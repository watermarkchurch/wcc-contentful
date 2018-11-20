# frozen_string_literal: true

module WCC::Contentful::ActiveRecordShim
  extend ActiveSupport::Concern

  def attributes
    @attributes ||= to_h['fields'].tap { |fields| fields['id'] = id }
  end

  class_methods do
    def model_name
      name
    end

    def table_name
      name.tableize
    end

    def unscoped
      yield
    end

    def find_in_batches(options, &block)
      options ||= {}
      batch_size = options.delete(:batch_size) || 1000
      filter = {
        options: {
          limit: batch_size,
          skip: options.delete(:start) || 0,
          include: options.delete(:include) || 1
        }
      }

      find_all(filter).each_slice(batch_size, &block)
    end
  end
end

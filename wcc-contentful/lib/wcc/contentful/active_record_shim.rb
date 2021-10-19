# frozen_string_literal: true

module WCC::Contentful::ActiveRecordShim
  extend ActiveSupport::Concern

  def attributes
    @attributes ||= to_h['fields'].tap { |fields| fields['id'] = id }
  end

  def cache_key
    return cache_key_with_version unless ActiveRecord::Base.try(:cache_versioning) == true

    "#{self.class.model_name}/#{id}"
  end

  def cache_key_with_version
    "#{cache_key_without_version}-#{cache_version}"
  end

  def cache_key_without_version
    "#{self.class.model_name}/#{id}"
  end

  def cache_version
    sys.revision.to_s
  end

  included do
    unless defined?(ActiveRecord)
      raise NotImplementedError, 'WCC::Contentful::ActiveRecordShim requires ActiveRecord to be loaded'
    end
  end

  class_methods do
    def model_name
      WCC::Contentful::Helpers.constant_from_content_type(content_type)
    end

    def const_get(name)
      # Because our pattern is `class MyModel < WCC::Contentful::Model::MyModel`
      # if you do MyModel.const_get('MyModel') Algolia expects you to return
      # ::MyModel not WCC::Contentful::Model::MyModel
      return self if name == model_name

      super
    end

    def table_name
      model_name.tableize
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

    def where(**conditions)
      # TODO: return a Query object that implements more of the ActiveRecord query interface
      # https://guides.rubyonrails.org/active_record_querying.html#conditions
      find_all(conditions)
    end
  end
end

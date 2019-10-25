# frozen_string_literal: true

require_relative '../instrumentation'

module WCC::Contentful::Store
  module Instrumentation
    extend ActiveSupport::Concern

    included do
      include WCC::Contentful::Instrumentation

      def _instrumentation_event_prefix
        '.store.contentful.wcc'
      end

      prepend InstrumentationWrapper
    end
  end

  module InstrumentationWrapper
    def find(key, **options)
      _instrument 'find', id: key, options: options do
        super
      end
    end

    def set(id, value)
      _instrument 'set', id: id do
        super
      end
    end

    def delete(id)
      _instrument 'delete', id: id do
        super
      end
    end

    def index(json)
      _instrument 'index', id: json.dig('sys', 'id') do
        super
      end
    end

    def find_by(**params)
      _instrument 'find_by', params.slice(:content_type, :filter, :options) do
        super
      end
    end

    def find_all(**params)
      _instrument 'find_all', params.slice(:content_type, :options) do
        super
      end
    end
  end
end

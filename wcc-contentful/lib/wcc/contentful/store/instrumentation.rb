# frozen_string_literal: true

require_relative '../instrumentation'
require_relative '../middleware/store'

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
      # end happens when query is executed - todo.
      _instrument 'find_all', params.slice(:content_type, :options)
      super
    end
  end

  class InstrumentationMiddleware
    include WCC::Contentful::Middleware::Store
    include WCC::Contentful::Store::Instrumentation

    delegate(*WCC::Contentful::Store::Interface::INTERFACE_METHODS, to: :store)

    # TODO: use DelegatingQuery to instrument the moment of find_all query execution?
  end
end

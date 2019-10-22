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
        super(key, **options)
      end
    end
  end
end

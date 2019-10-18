# frozen_string_literal: true

module WCC::Contentful
  module Instrumentation
    extend ActiveSupport::Concern

    def instrumentation_event_prefix
      @instrumentation_event_prefix ||=
        # WCC::Contentful => contentful.wcc
        '.' + self.class.name.parameterize.split('-').reverse.join('.')
    end

    included do
      private

      def instrument(name, payload = {}, &block)
        name += instrumentation_event_prefix
        (@_instrumentation ||= ActiveSupport::Notifications)
          .instrument(name, payload, &block)
      end
    end
  end
end

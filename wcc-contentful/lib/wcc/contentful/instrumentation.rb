# frozen_string_literal: true

module WCC::Contentful
  module Instrumentation
    extend ActiveSupport::Concern

    def _instrumentation_event_prefix
      @_instrumentation_event_prefix ||=
        # WCC::Contentful => contentful.wcc
        '.' + (is_a?(Class) || is_a?(Module) ? self : self.class)
          .name.parameterize.split('-').reverse.join('.')
    end

    included do
      protected

      def _instrument(name, payload = {}, &block)
        name += _instrumentation_event_prefix
        (@_instrumentation ||= WCC::Contentful::Services.instance.instrumentation)
          .instrument(name, payload, &block)
      end
    end

    class << self
      def instrument(name, payload = {}, &block)
        # TODO: load config
        WCC::Contentful::Services.instance
          .instrumentation.instrument(name, payload, &block)
      end
    end
  end
end

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

    attr_writer :_instrumentation
    def _instrumentation
      # look for per-instance instrumentation then try class level
      @_instrumentation || self.class._instrumentation
    end

    included do
      protected

      def _instrument(name, payload = {}, &block)
        name += _instrumentation_event_prefix
        _instrumentation&.instrument(name, payload, &block)
      end
    end

    class_methods do
      attr_writer :_instrumentation

      def _instrumentation
        @_instrumentation ||
          # try looking up the class heierarchy
          superclass.try(:_instrumentation) ||
          # default to global
          WCC::Contentful::Services.instance&.instrumentation_adapter ||
          ActiveSupport::Notifications
      end
    end

    class << self
      def instrument(name, payload = {}, &block)
        WCC::Contentful::Services.instance
          .instrumentation.instrument(name, payload, &block)
      end
    end
  end
end

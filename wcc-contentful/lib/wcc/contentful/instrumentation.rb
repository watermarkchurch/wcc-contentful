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
        self.class._instrumentation&.instrument(name, payload, &block)
      end
    end

    class_methods do
      attr_writer :_instrumentation

      def _instrumentation
        @_instrumentation ||=
          # try looking up the class heierarchy
          superclass.try(:_instrumentation) ||
          # see if we have a services
          try(:services)&.instrumentation ||
          # default to global
          WCC::Contentful::Services.instance.instrumentation
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

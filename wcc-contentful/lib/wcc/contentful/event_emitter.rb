# frozen_string_literal: true

module WCC::Contentful::EventEmitter
  extend ActiveSupport::Concern

  included do
    def add_listener(event, listener)
      listener_id = [event, listener.object_id].join(':')
      listeners = __listeners.compute_if_absent(event) { Concurrent::Array.new }
      listeners << {
        id: listener_id,
        event: event,
        listener: listener
      }
      listener_id
    end

    def remove_listener(id)
      event, = id.split(':')
      return unless listeners = __listeners[event]

      listener = listeners.find { |l| l[:id] == id }
      listeners.delete(listener)
    end

    def emit(event, *args)
      return unless listeners = __listeners[event]

      # emit over a snapshot of the listeners
      listeners.dup.each do |l|
        begin
          l[:listener].call(*args)
        rescue StandardError => e
          msg = "Failure on event '#{event}' emitted by #{self.class.name}:\n  #{e}"
          warn msg
        end
      end
    end

    private

    def __listeners
      @__listeners ||= Concurrent::Map.new
    end
  end
end

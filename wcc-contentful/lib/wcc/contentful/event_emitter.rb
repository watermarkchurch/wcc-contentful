# frozen_string_literal: true

module WCC::Contentful::EventEmitter
  extend ActiveSupport::Concern

  included do
    def add_listener(event, listener)
      raise ArgumentError, 'event must be specified' unless event
      raise ArgumentError, 'listener must be provided' unless listener

      event = event.to_s

      listener_id = [event, listener.object_id].join(':')
      listeners = __listeners.compute_if_absent(event) { Concurrent::Array.new }
      listeners << {
        id: listener_id,
        event: event,
        listener: listener
      }
      listener_id
    end

    def on(event, listener = nil, &block)
      raise ArgumentError, 'listener block must be given' unless listener || block_given?

      add_listener(event, listener || Proc.new(&block))
    end

    def once(event, listener = nil, &block)
      raise ArgumentError, 'listener block must be given' unless listener || block_given?

      id = ''
      emitter = self
      listener ||= Proc.new(&block)
      id = add_listener(event,
        proc { |*args|
          begin
            listener.call(*args)
          ensure
            emitter.remove_listener(id)
          end
        })
    end

    def remove_listener(id)
      event, = id.split(':')
      return unless listeners = __listeners[event]

      listener = listeners.find { |l| l[:id] == id }
      listeners.delete(listener)
    end

    def has_listeners?(event = nil) # rubocop:disable Naming/PredicateName preference in this instance
      return __listeners[event].present? if event

      __listeners.values.any? { |arr| !arr.empty? }
    end

    def emit(event, *args)
      raise ArgumentError, 'event must be specified' unless event

      event = event.to_s
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

    def ensure_removed(listener_id)
    end
  end
end

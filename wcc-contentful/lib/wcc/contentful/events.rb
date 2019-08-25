# typed: true
# frozen_string_literal: true

require 'wisper'
require 'singleton'

# WCC::Contentful::Events is a singleton which rebroadcasts Contentful update
# events.  You can subscribe to these events in your initializer using the
# [wisper gem syntax](https://github.com/krisleech/wisper).
# All published events are in the namespace WCC::Contentful::Event.
class WCC::Contentful::Events
  include Wisper::Publisher

  def self.instance
    @instance ||= new
  end

  def initialize
    _attach_listeners
  end

  def rebroadcast(event)
    type = event.dig('sys', 'type')
    raise ArgumentError, "Unknown event type #{event}" unless type.present?

    broadcast(type, event)
  end

  private

  def _attach_listeners
    publishers = [
      WCC::Contentful::Services.instance.sync_engine
    ]

    publishers << WCC::Contentful::WebhookController if defined?(Rails)

    publishers.each do |publisher|
      publisher.subscribe(self, with: :rebroadcast) if publisher.present?
    end
  end
end

# frozen_string_literal: true

require 'wisper'
require 'singleton'

# WCC::Contentful::Events is a singleton which rebroadcasts Contentful update
# events.  You can subscribe to these events in your initializer using the
# [wisper gem syntax](https://github.com/krisleech/wisper).
# All published events are in the namespace WCC::Contentful::Event.
class WCC::Contentful::Events
  include Singleton
  include Wisper::Publisher

  def initialize
    [
      WCC::Contentful::Services.sync_engine,
      WCC::Contentful::WebhookController
    ].each do |publisher|
      publisher.subscribe(:self, with: :rebroadcast)
    end
  end

  def rebroadcast(event)
    type = event.dig('sys', 'type')
    raise ArgumentError, "Unknown event type #{event}" unless type.present?

    broadcast(type, event)
  end
end

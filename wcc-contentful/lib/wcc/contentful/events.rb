# frozen_string_literal: true

require 'wisper'
require 'singleton'

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

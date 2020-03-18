# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::Events do
  describe '.initialize' do
    it 'rebroadcasts sync engine events' do
      client = double('client')
      sync_engine = WCC::Contentful::SyncEngine.new(state: 'start-token', client: client)
      allow(WCC::Contentful::Services.instance).to receive(:sync_engine)
        .and_return(sync_engine)

      allow(client).to receive(:sync)
        .and_return(
          double('response',
            items: [
              {
                'sys' => {
                  'id' => '1234',
                  'type' => 'DeletedEntry'
                }
              }
            ],
            next_sync_token: 'next-token')
        )

      subscriber = double('subscriber')
      expect(subscriber).to receive(:DeletedEntry)

      instance = WCC::Contentful::Events.new
      instance.subscribe(subscriber)

      sync_engine.next
    end

    it 'rebroadcasts webhook events', rails: true do
      controller = WCC::Contentful::WebhookController.new
      subscriber = double('subsc 2')
      expect(subscriber).to receive(:Entry)

      allow(WCC::Contentful::Services.instance).to receive(:sync_engine)
        .and_return(double('sync_engine', subscribe: nil))

      instance = WCC::Contentful::Events.new
      instance.subscribe(subscriber)

      Wisper::GlobalListeners.registrations.each do |registration|
        registration.broadcast('Entry', controller, {
          'sys' => {
            'id' => '1234',
            'type' => 'Entry'
          }
        })
      end
    end
  end
end

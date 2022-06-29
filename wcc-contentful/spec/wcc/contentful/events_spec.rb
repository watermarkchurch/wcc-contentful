# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::Events do
  describe '.initialize' do
    it 'rebroadcasts sync engine events' do
      client = double('client')
      sync_engine = WCC::Contentful::SyncEngine.new(state: 'start-token', client: client)
      services = double(
        client: client,
        sync_engine: sync_engine
      )
      allow(WCC::Contentful::Services).to receive(:instance)
        .and_return(services)

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
      events = []
      allow(subscriber).to receive(:call) do |e|
        events << e
      end

      instance = WCC::Contentful::Events.new
      instance.subscribe(subscriber, with: :call)

      # act
      sync_engine.next

      # assert
      expect(events[0]).to be_a(WCC::Contentful::Event::DeletedEntry)
      expect(events[0].source).to eq(sync_engine)

      expect(events[1]).to be_a(WCC::Contentful::Event::SyncComplete)
      expect(events[1].source).to eq(sync_engine)
      expect(events[1].items[0].source).to eq(sync_engine)
    end

    it 'rebroadcasts webhook events', rails: true do
      controller = WCC::Contentful::WebhookController.new
      subscriber = double('subsc 2')
      expect(subscriber).to receive(:Entry)

      sync_engine = double('sync_engine', subscribe: nil)
      allow(WCC::Contentful::Services).to receive(:instance)
        .and_return(double(sync_engine: sync_engine))

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

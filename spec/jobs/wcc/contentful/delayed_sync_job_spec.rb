# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::DelayedSyncJob, type: :job do
  ActiveJob::Base.queue_adapter = :test
  described_class.queue_adapter = :test

  let(:next_sync) { JSON.parse(load_fixture('contentful/sync_continue.json')) }

  subject(:job) { described_class.new }

  let(:client) { double }
  let(:store) { double(find: nil, index: nil, set: nil) }

  before do
    allow(WCC::Contentful::Services.instance).to receive(:store)
      .and_return(store)

    allow(WCC::Contentful::Services.instance).to receive(:client)
      .and_return(client)
  end

  describe '.sync!' do
    context 'when no ID given' do
      it 'does nothing if no sync data available' do
        allow(client).to receive(:sync)
          .and_return(double(
                        items: [],
                        next_sync_token: 'test'
                      ))

        expect(WCC::Contentful::Services.instance.store).to receive(:set)
          .with('sync:token', 'test')
        expect(WCC::Contentful::Services.instance.store).to_not receive(:index)

        # act
        synced = job.sync!

        # assert
        expect(synced).to eq('test')
      end

      it 'updates the store with the latest data' do
        allow(store).to receive(:find)
          .with('sync:token')
          .and_return('test1')

        allow(client).to receive(:sync)
          .with(sync_token: 'test1')
          .and_return(double(
                        items: next_sync['items'],
                        next_sync_token: 'test2'
                      ))

        items = next_sync['items']
        expect(WCC::Contentful::Services.instance.store).to receive(:set)
          .with('sync:token', 'test2')
        expect(WCC::Contentful::Services.instance.store).to receive(:index)
          .exactly(items.count).times

        # act
        job.sync!
      end
    end

    context 'when ID given' do
      it 'does not drop a job if the ID comes back in the sync' do
        allow(client).to receive(:sync)
          .and_return(double(
                        items: next_sync['items'],
                        next_sync_token: 'test2'
                      ))

        expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
        expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)

        # act
        job.sync!(up_to_id: '1EjBdAgOOgAQKAggQoY2as')
      end
    end

    it 'Drops the job again if the ID still does not come back' do
      allow(client).to receive(:sync)
        .and_return(double(
                      items: next_sync['items'],
                      next_sync_token: 'test2'
                    ))

      # expect
      expect(job).to receive(:sync_later!)
        .with(up_to_id: 'foobar')

      # act
      job.sync!(up_to_id: 'foobar')
    end
  end

  describe 'Perform' do
    it 'calls into job.sync!' do
      expect_any_instance_of(described_class)
        .to receive(:sync!)
        .with(up_to_id: nil)

      # act
      described_class.perform_now
    end

    it 'calls into job.sync! with explicit params' do
      expect_any_instance_of(described_class)
        .to receive(:sync!)
        .with(up_to_id: 'asdf')

      # act
      described_class.perform_now(up_to_id: 'asdf')
    end

    it 'calls into job.sync! with webhook event' do
      expect_any_instance_of(described_class)
        .to receive(:sync!)
        .with(up_to_id: 'testId1')

      # act
      described_class.perform_now({
        'sys' => {
          'id' => 'testId1'
        }
      })
    end
  end
end

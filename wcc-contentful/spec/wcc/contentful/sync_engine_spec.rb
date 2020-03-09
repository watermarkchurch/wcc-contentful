# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::SyncEngine::Job, type: :job do
  ActiveJob::Base.queue_adapter = :test
  described_class.queue_adapter = :test

  let(:next_sync) { JSON.parse(load_fixture('contentful/sync_continue.json')) }

  subject(:job) { described_class.new }

  let(:client) { double }
  let(:store) { double(find: nil, index: nil, index?: true, set: nil) }
  let(:sync_engine) {
    WCC::Contentful::SyncEngine.new(
      store: store,
      client: client,
      key: 'sync:token'
    )
  }

  before do
    allow(WCC::Contentful::Services.instance).to receive(:store)
      .and_return(store)

    allow(WCC::Contentful::Services.instance).to receive(:client)
      .and_return(client)

    allow(WCC::Contentful::Services.instance).to receive(:sync_engine)
      .and_return(sync_engine)

    described_class.instance_variable_set('@sync_engine', nil)
  end

  describe '.sync!' do
    context 'when no ID given' do
      it 'does nothing if no sync data available' do
        allow(client).to receive(:sync)
          .and_return(double(
                        items: [],
                        next_sync_token: 'test'
                      ))

        expect(store).to receive(:index)
          .once
          .with({ 'sys' => { 'id' => 'sync:token', 'type' => 'token' }, 'token' => 'test' })

        # act
        synced = job.sync!

        # assert
        expect(synced).to eq('test')
      end

      it 'updates the store with the latest data' do
        allow(store).to receive(:find)
          .with('sync:token')
          .and_return({ 'token' => 'test1' })

        allow(client).to receive(:sync)
          .with(sync_token: 'test1')
          .and_return(double(
                        items: next_sync['items'],
                        next_sync_token: 'test2'
                      ))

        items = next_sync['items']
        expect(store).to receive(:index)
          .with({ 'sys' => { 'type' => 'token', 'id' => 'sync:token' }, 'token' => 'test2' })
        expect(store).to receive(:index)
          .exactly(items.count).times

        # act
        job.sync!
      end

      it 'emits each item returned by the sync' do
        allow(client).to receive(:sync)
          .and_return(double(
                        items: next_sync['items'],
                        next_sync_token: 'test2'
                      ))

        emitted_entries = []
        sync_engine.on('Entry') { |item| emitted_entries << item }
        emitted_assets = []
        sync_engine.on('Asset') { |item| emitted_assets << item }
        emitted_deletions = []
        sync_engine.on('DeletedEntry') { |item| emitted_deletions << item }
        emitted_deletions = []
        sync_engine.on('DeletedAsset') { |item| emitted_deletions << item }

        # act
        job.sync!

        expect(emitted_entries.count).to eq(2)
        expect(emitted_assets.count).to eq(0)
        expect(emitted_deletions.count).to eq(12)

        emitted0 = emitted_entries[0]
        expect(emitted0).to be_a WCC::Contentful::Event::Entry
        expect(emitted0.source).to eq(sync_engine)

        expect(emitted_entries.dig(0, 'sys', 'id')).to eq('47PsST8EicKgWIWwK2AsW6')
        expect(emitted0['sys']['id']).to eq('47PsST8EicKgWIWwK2AsW6')
        expect(emitted0.id).to eq('47PsST8EicKgWIWwK2AsW6')

        expect(emitted_entries.dig(1, 'sys', 'id')).to eq('1qLdW7i7g4Ycq6i4Cckg44')
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

    it 'Drops the job again if the ID still does not come back and told to go again' do
      allow(client).to receive(:sync)
        .and_return(double(
                      items: next_sync['items'],
                      next_sync_token: 'test2'
                    ))

      # expect
      expect(job).to receive(:sync_later!)
        .with(up_to_id: nil)

      # act
      job.sync!(up_to_id: 'foobar')
    end

    it 'does not drop a job if the ID is nil' do
      allow(client).to receive(:sync)
        .and_return(double(
                      items: next_sync['items'],
                      next_sync_token: 'test2'
                    ))

      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)

      # act
      job.sync!(up_to_id: nil)
    end

    context 'with :lazy_cache' do
      let(:cache) {
        ActiveSupport::Cache::MemoryStore.new
      }

      let(:store) {
        WCC::Contentful::Middleware::Store::CachingMiddleware.new(cache).tap do |middleware|
          middleware.store = WCC::Contentful::Store::CDNAdapter.new(client)
        end
      }

      it 'continues from prior sync token with CachingMiddleware' do
        allow(client).to receive(:sync)
          .with({ sync_token: nil })
          .and_return(double(
                        items: [],
                        next_sync_token: 'test'
                      ))
        expect(client).to receive(:sync)
          .with({ sync_token: 'test' })
          .and_return(double(
                        items: [],
                        next_sync_token: 'test2'
                      ))

        # act
        synced = job.sync!
        synced2 = job.sync!

        # assert
        expect(synced).to eq('test')
        expect(synced2).to eq('test2')
      end

      it 'ignores a poison sync token in the store' do
        cache.write('sync:token', poison: 'poison')

        expect(client).to receive(:sync)
          .with({ sync_token: nil })
          .and_return(double(
                        items: [],
                        next_sync_token: 'test'
                      ))

        # act
        synced = job.sync!

        # assert
        expect(synced).to eq('test')
      end
    end

    context 'with a non-indexable store (i.e. CDNAdapter)' do
      let(:store) {
        double(index: nil, index?: false, find: nil)
      }

      it 'does not update the store' do
        expect(store).to_not receive(:index)

        allow(store).to receive(:find)
          .with('sync:token')
          .and_return({ 'token' => 'test1' })
        allow(client).to receive(:sync)
          .with(sync_token: 'test1')
          .and_return(double(
                        items: next_sync['items'],
                        next_sync_token: 'test2'
                      ))

        # act
        job.sync!
      end

      it 'emits each item returned by the sync' do
        allow(client).to receive(:sync)
          .and_return(double(
                        items: next_sync['items'],
                        next_sync_token: 'test2'
                      ))

        emitted_entries = []
        sync_engine.on('Entry') { |item| emitted_entries << item }
        emitted_assets = []
        sync_engine.on('Asset') { |item| emitted_assets << item }
        emitted_deletions = []
        sync_engine.on('DeletedEntry') { |item| emitted_deletions << item }
        emitted_deletions = []
        sync_engine.on('DeletedAsset') { |item| emitted_deletions << item }

        # act
        job.sync!

        expect(emitted_entries.count).to eq(2)
        expect(emitted_assets.count).to eq(0)
        expect(emitted_deletions.count).to eq(12)
      end
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

  describe 'sync_later!' do
    it 'drops another job with the given ID in 10 minutes' do
      configured_job = double

      expect(described_class).to receive(:set)
        .with(wait: 10.minutes)
        .and_return(configured_job)
      expect(configured_job).to receive(:perform_later)
        .with(up_to_id: 'foobar')

      # act
      job.sync_later!(up_to_id: 'foobar')
    end
  end
end

# frozen_string_literal: true

require 'job_helper'

require 'wcc/contentful/sync_engine'

RSpec.describe 'WCC::Contentful::SyncEngine::Job', type: :job do
  let(:described_class) { WCC::Contentful::SyncEngine::Job }

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

  let(:configuration) {
    WCC::Contentful::Configuration.new
  }

  before do
    allow(WCC::Contentful::Services).to receive(:instance)
      .and_return(double(
        configuration: configuration,
        store: store,
        client: client,
        sync_engine: sync_engine,
        instrumentation: ActiveSupport::Notifications
      ))

    allow(WCC::Contentful).to receive(:configuration)
      .and_return(configuration)

    described_class.instance_variable_set('@sync_engine', nil)
  end

  describe '.sync!' do
    context 'when no ID given' do
      it 'does nothing if no sync data available' do
        allow(client).to receive(:sync)
          .and_return('test')

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

        stub = allow(client).to receive(:sync)
          .with(sync_token: 'test1')
          .and_return('test2')
        next_sync['items'].reduce(stub) do |s, item|
          s.and_yield(item)
        end

        items = next_sync['items']
        expect(store).to receive(:index)
          .with({ 'sys' => { 'type' => 'token', 'id' => 'sync:token' }, 'token' => 'test2' })
        expect(store).to receive(:index)
          .exactly(items.count).times

        # act
        job.sync!
      end

      it 'emits each item returned by the sync' do
        stub = allow(client).to receive(:sync)
          .and_return('test2')
        next_sync['items'].reduce(stub) do |s, item|
          s.and_yield(item)
        end

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

      it 'emits sync complete event' do
        stub = allow(client).to receive(:sync)
          .and_return('test2')
        next_sync['items'].reduce(stub) do |s, item|
          s.and_yield(item)
        end

        sync_complete_events = []
        sync_engine.on('SyncComplete') { |item| sync_complete_events << item }

        # act
        job.sync!

        expect(sync_complete_events.count).to eq(1)

        emitted0 = sync_complete_events[0]
        expect(emitted0).to be_a WCC::Contentful::Event::SyncComplete
        expect(emitted0.source).to eq(sync_engine)
        expect(emitted0.items.length).to eq(14)

        expect(emitted0.items.dig(0, 'sys', 'id')).to eq('47PsST8EicKgWIWwK2AsW6')
        expect(emitted0.items.dig(1, 'sys', 'id')).to eq('6HQsABhZDiWmi0ekCouUuy')
      end
    end

    context 'when ID given' do
      it 'does not enqueue a job if the ID comes back in the sync' do
        stub = allow(client).to receive(:sync)
          .and_return('test2')
        next_sync['items'].reduce(stub) do |s, item|
          s.and_yield(item)
        end

        expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
        expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)

        # act
        job.sync!(up_to_id: '1EjBdAgOOgAQKAggQoY2as')
      end
    end

    it 'Enqueues the job again if the ID still does not come back and told to go again' do
      stub = allow(client).to receive(:sync)
        .and_return('test2')
      next_sync['items'].reduce(stub) do |s, item|
        s.and_yield(item)
      end

      # expect
      configured_job = double

      expect(described_class).to receive(:set)
        .with(wait: 1.second)
        .and_return(configured_job)
      expect(configured_job).to receive(:perform_later)
        .with(up_to_id: 'foobar', retry_count: 1)

      # act
      job.sync!(up_to_id: 'foobar')
    end

    it 'Enqueues the job with exponential backoff if retry count is less than maximum' do
      stub = allow(client).to receive(:sync)
        .and_return('test2')
      next_sync['items'].reduce(stub) do |s, item|
        s.and_yield(item)
      end

      # expect
      configured_job = double

      expect(described_class).to receive(:set)
        .with(wait: 2.seconds)
        .and_return(configured_job)
      expect(configured_job).to receive(:perform_later)
        .with(up_to_id: 'foobar', retry_count: 2)

      # act
      job.sync!(up_to_id: 'foobar', retry_count: 1)
    end

    it 'Does not reenqueue the job if retry_count is at the limit' do
      stub = allow(client).to receive(:sync)
        .and_return('test2')
      next_sync['items'].reduce(stub) do |s, item|
        s.and_yield(item)
      end

      # expect
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)
      expect(described_class).to_not receive(:set)

      # act
      job.sync!(up_to_id: 'foobar', retry_count: 3)
    end

    it 'does not reenqueue a job if the ID is nil' do
      stub = allow(client).to receive(:sync)
        .and_return('test2')
      next_sync['items'].reduce(stub) do |s, item|
        s.and_yield(item)
      end

      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)
      expect(described_class).to_not receive(:set)

      emitted_entries = []
      sync_engine.on('Entry') { |item| emitted_entries << item }

      # act
      job.sync!(up_to_id: nil)

      expect(emitted_entries.count).to eq(2)
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
          .and_return('test')
        expect(client).to receive(:sync)
          .with({ sync_token: 'test' })
          .and_return('test2')

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
          .and_return('test')

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

        stub = allow(client).to receive(:sync)
          .with(sync_token: 'test1')
          .and_return('test2')
        next_sync['items'].reduce(stub) do |s, item|
          s.and_yield(item)
        end

        # act
        job.sync!
      end

      it 'emits each item returned by the sync' do
        stub = allow(client).to receive(:sync)
          .and_return('test2')
        next_sync['items'].reduce(stub) do |s, item|
          s.and_yield(item)
        end

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
      expect(job)
        .to receive(:sync!)
        .with(up_to_id: nil, retry_count: 0)

      # act
      job.perform
    end

    it 'calls into job.sync! with explicit params' do
      expect(job)
        .to receive(:sync!)
        .with(up_to_id: 'asdf', retry_count: 1)

      # act
      job.perform(up_to_id: 'asdf', retry_count: 1)
    end

    it 'calls into job.sync! with webhook event' do
      expect(job)
        .to receive(:sync!)
        .with(up_to_id: 'testId1', retry_count: 0)

      # act
      job.perform({
        'sys' => {
          'id' => 'testId1'
        }
      })
    end
  end

  describe 'sync_later!' do
    it 'enqueues another job with the given ID in 10 seconds' do
      configured_job = double

      expect(described_class).to receive(:set)
        .with(wait: 10.seconds)
        .and_return(configured_job)
      expect(configured_job).to receive(:perform_later)
        .with(up_to_id: 'foobar')

      # act
      job.sync_later!(up_to_id: 'foobar')
    end
  end
end

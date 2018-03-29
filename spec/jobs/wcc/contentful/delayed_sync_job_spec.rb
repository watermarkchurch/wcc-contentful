# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::DelayedSyncJob, type: :job do
  ActiveJob::Base.queue_adapter = :test

  let(:empty) { JSON.parse(load_fixture('contentful/sync_empty.json')) }
  let(:next_sync) { JSON.parse(load_fixture('contentful/sync_continue.json')) }

  before do
    stub_request(:get,
      "https://cdn.contentful.com/spaces/#{contentful_space_id}/content_types?limit=1000")
      .to_return(body: load_fixture('contentful/content_types_cdn.json'))

    # initial sync
    stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
      .with(query: hash_including('initial' => 'true'))
      .to_return(body: load_fixture('contentful/sync.json'))

    # first empty sync
    stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
      .with(query: hash_including('sync_token' => 'w5ZGw...'))
      .to_return(body: load_fixture('contentful/sync_empty.json'))

    WCC::Contentful.configure do |config|
      config.access_token = contentful_access_token
      config.space = contentful_space_id
      config.management_token = nil
      config.default_locale = nil
      config.content_delivery = :eager_sync
      config.sync_store = :memory
    end

    WCC::Contentful.init!
  end

  describe 'WCC::Contentful.sync!' do
    it 'Drops the job again if the ID still does not come back' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
        .with(query: hash_including('sync_token' => 'FwqZm...'))
        .to_return(body: next_sync.merge({ 'nextSyncUrl' =>
          "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=test1" }).to_json)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
        .with(query: hash_including('sync_token' => 'test1'))
        .to_return(body: empty.merge({ 'nextSyncUrl' =>
          "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=test2" }).to_json)

      # act
      expect {
        WCC::Contentful.sync!(up_to_id: 'foobar')
      }.to have_enqueued_job(described_class)
    end
  end

  describe 'Perform' do
    it 'calls into WCC::Contentful.sync!' do
      expect(WCC::Contentful).to receive(:sync!)

      # act
      described_class.perform_now
    end

    it 'calls into WCC::Contentful.sync! with params' do
      expect(WCC::Contentful).to receive(:sync!)
        .with(up_to_id: 'asdf')

      # act
      described_class.perform_now(up_to_id: 'asdf')
    end
  end
end

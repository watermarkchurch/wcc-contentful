# frozen_string_literal: true

require 'spec_helper'
require 'wcc/contentful/middleman/extension'

RSpec.describe WCC::Contentful::Middleman::Extension do
  let(:app) {
    double('app', after_configuration: nil, ready: nil)
  }

  describe '#initialize' do
    before do
      stub_request(:get, /https:\/\/cdn.contentful.com\/spaces\/.+\/sync/)
        .to_return(body: load_fixture('contentful/sync.json'))
    end

    it 'sets contentful config variables' do
      described_class.new(app,
        space: 'testspace',
        access_token: 'testtoken1',
        preview_token: 'testpreview1',
        management_token: 'testmgmt1')

      expect(WCC::Contentful.configuration.space).to eq('testspace')
      expect(WCC::Contentful.configuration.access_token).to eq('testtoken1')
      expect(WCC::Contentful.configuration.preview_token).to eq('testpreview1')
      expect(WCC::Contentful.configuration.management_token).to eq('testmgmt1')
    end

    it 'infers from environment variables' do
      described_class.new(app)

      expect(WCC::Contentful.configuration.space).to eq('test1xab')
      expect(WCC::Contentful.configuration.access_token).to eq('test1234')
      expect(WCC::Contentful.configuration.preview_token).to eq('test123456')
      expect(WCC::Contentful.configuration.management_token).to eq('CFPAT-test1234')
    end

    it 'sets configuration defaults' do
      described_class.new(app)

      # middleman uses memory store by default to sync all content over
      store = WCC::Contentful::Services.instance.store.store
      expect(store).to be_a WCC::Contentful::Middleware::Store::LocaleMiddleware
      expect(store.store).to be_a WCC::Contentful::Store::MemoryStore
    end

    it 'passes block' do
      described_class.new(app) do |config|
        config.environment = 'test123'
      end

      expect(WCC::Contentful.configuration.environment).to eq('test123')
    end

    it 'initializes WCC::Contentful' do
      expect(WCC::Contentful).to receive(:init!)

      described_class.new(app)
    end

    it 'syncs over new content' do
      described_class.new(app)

      store = WCC::Contentful::Services.instance.store
      homepage = store.find('4ssPJYNGPYQMMwo2gKmISo')
      expect(homepage).to be_present
    end
  end
end

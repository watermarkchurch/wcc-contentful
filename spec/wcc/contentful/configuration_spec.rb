# frozen_string_literal: true

RSpec.describe WCC::Contentful::Configuration do
  subject(:config) { WCC::Contentful::Configuration.new }

  describe '#content_delivery' do
    it 'raises error when setting invalid content delivery method' do
      expect {
        config.content_delivery = :asdf
      }.to raise_error(ArgumentError)
    end

    it 'raises error when setting a store to content_delivery' do
      # act
      expect {
        config.content_delivery = WCC::Contentful::Store::MemoryStore.new
      }.to raise_error(ArgumentError)
    end

    it 'allows setting a custom store to store=' do
      store = double

      # act
      config.store = store

      # assert
      expect(config.content_delivery).to eq(:custom)
      expect(config.store).to be(store)
    end

    context 'eager sync' do
      it 'selects store from symbol' do
        # act
        config.content_delivery = :eager_sync, :postgres

        # assert
        expect(config.content_delivery).to eq(:eager_sync)
        expect(config.store).to be_a(WCC::Contentful::Store::PostgresStore)
      end

      it 'uses provided store' do
        store = double

        # act
        config.content_delivery = :eager_sync, store

        # assert
        expect(config.content_delivery).to eq(:eager_sync)
        expect(config.store).to be(store)
      end

      it 'errors when using a bad store' do
        # act
        expect {
          config.content_delivery = :eager_sync, :asdf
        }.to raise_error(ArgumentError)
      end
    end

    context 'lazy sync' do
      it 'looks up cache from activesupport' do
        cache = double(fetch: 'test data')
        expect(ActiveSupport::Cache).to receive(:lookup_store)
          .with(:file_store, '/tmp/cache')
          .and_return(cache)

        # act
        config.content_delivery = :lazy_sync, :file_store, '/tmp/cache'

        # assert
        expect(config.content_delivery).to eq(:lazy_sync)
        expect(config.store).to be_a(WCC::Contentful::Store::LazyCacheStore)
        expect(config.store.find('test')).to eq('test data')
      end

      it 'uses provided cache' do
        cache = double(fetch: 'test data')

        # act
        config.content_delivery = :lazy_sync, cache

        # assert
        expect(config.content_delivery).to eq(:lazy_sync)
        expect(config.store).to be_a(WCC::Contentful::Store::LazyCacheStore)
        expect(config.store.find('test')).to eq('test data')
      end
    end

    context 'direct' do
      it 'uses CDN adapter' do
        # act
        config.content_delivery = :direct

        # assert
        expect(config.content_delivery).to eq(:direct)
        expect(config.store).to be_a(WCC::Contentful::Store::CDNAdapter)
      end
    end
  end
end

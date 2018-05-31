# frozen_string_literal: true

RSpec.describe WCC::Contentful::Configuration do
  subject(:config) { WCC::Contentful::Configuration.new }

  let(:services) { WCC::Contentful::Services.instance }

  before do
    allow(WCC::Contentful).to receive(:configuration)
      .and_return(config)
  end

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
      expect(services.store).to be(store)
    end

    it 'allows setting a store class with parameters to store=' do
      store_class =
        Class.new do
          attr_accessor :config
          attr_accessor :params

          def initialize(config, params)
            @config = config
            @params = params
          end
        end

      # act
      config.store = store_class, :param_1, 'param_2'

      # assert
      expect(config.content_delivery).to eq(:custom)
      expect(services.store).to be_a(store_class)
      expect(services.store.params).to eq([:param_1, 'param_2'])
    end

    context 'eager sync' do
      it 'selects store from symbol' do
        # act
        config.content_delivery = :eager_sync, :postgres

        # assert
        expect(config.content_delivery).to eq(:eager_sync)
        expect(services.store).to be_a(WCC::Contentful::Store::PostgresStore)
      end

      it 'uses provided store' do
        store = double

        # act
        config.content_delivery = :eager_sync, store

        # assert
        expect(config.content_delivery).to eq(:eager_sync)
        expect(services.store).to be(store)
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
        store = services.store
        expect(store).to be_a(WCC::Contentful::Store::LazyCacheStore)
        expect(store.find('test')).to eq('test data')
      end

      it 'uses provided cache' do
        cache = double(fetch: 'test data')

        # act
        config.content_delivery = :lazy_sync, cache

        # assert
        expect(config.content_delivery).to eq(:lazy_sync)
        store = services.store
        expect(store).to be_a(WCC::Contentful::Store::LazyCacheStore)
        expect(store.find('test')).to eq('test data')
      end
    end

    context 'direct' do
      it 'uses CDN adapter' do
        # act
        config.content_delivery = :direct

        # assert
        expect(config.content_delivery).to eq(:direct)
        store = services.store
        expect(store).to be_a(WCC::Contentful::Store::CDNAdapter)
      end
    end
  end
end

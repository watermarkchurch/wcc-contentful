# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::Configuration do
  subject(:config) { WCC::Contentful::Configuration.new }

  let(:services) { WCC::Contentful::Services.instance }

  before do
    allow(WCC::Contentful).to receive(:configuration)
      .and_return(config)
  end

  describe '#store' do
    it 'raises error when setting invalid content delivery method' do
      config.store :asdf
      expect {
        config.store.validate!
      }.to raise_error(ArgumentError)
    end

    it 'allows setting a custom store to store=' do
      store_class =
        Class.new do
          include WCC::Contentful::Store::Interface
        end

      store = store_class.new

      # act
      config.store = store

      # assert
      config.store.validate!
      stack = middleware_stack(services.store)
      expect(stack.last).to be(store)
    end

    it 'allows setting a store class with parameters to store=' do
      store_class =
        Class.new do
          include WCC::Contentful::Store::Interface
          attr_reader :config
          attr_reader :params

          attr_accessor :client

          def initialize(config, param1, param2)
            @config = config
            @params = [param1, param2]
          end
        end

      # act
      config.store = store_class, :param_1, 'param_2'

      # assert
      config.store.validate!
      stack = middleware_stack(services.store)
      store = stack.last
      expect(store).to be_a(store_class)
      expect(store.params).to eq([:param_1, 'param_2'])
      expect(store.client).to eq(WCC::Contentful::Services.instance.client)
    end

    context 'eager sync' do
      it 'selects store from symbol' do
        # act
        config.store :eager_sync, :postgres, ENV['POSTGRES_CONNECTION']

        # assert
        stack = middleware_stack(services.store)
        expect(stack.last).to be_a(WCC::Contentful::Store::PostgresStore)
      end

      it 'uses provided store' do
        store = double

        # act
        config.store :eager_sync, store

        # assert
        stack = middleware_stack(services.store)
        expect(stack.last).to be(store)
      end

      it 'errors when using a bad store' do
        config.store :eager_sync, :asdf

        # act
        expect {
          config.validate!
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
        config.store :lazy_sync, :file_store, '/tmp/cache'

        # assert
        stack = middleware_stack(services.store)
        expect(stack[stack.length - 2]).to be_a(WCC::Contentful::Middleware::Store::CachingMiddleware)
        expect(services.store.find('test')).to eq('test data')
      end

      it 'uses provided cache' do
        cache = double(fetch: 'test data')

        # act
        config.store :lazy_sync, cache

        # assert
        stack = middleware_stack(services.store)
        expect(stack[stack.length - 2]).to be_a(WCC::Contentful::Middleware::Store::CachingMiddleware)
        expect(services.store.find('test')).to eq('test data')
      end
    end

    context 'direct' do
      it 'uses CDN adapter' do
        # act
        config.store :direct

        # assert
        stack = middleware_stack(services.store)
        store = stack.last
        expect(store).to be_a(WCC::Contentful::Store::CDNAdapter)
      end
    end
  end

  describe '#middleware' do
    Test_Middleware =
      Class.new do
        include WCC::Contentful::Middleware::Store
      end

    it 'applies a middleware to the configured store' do
      config.store :direct do
        use Test_Middleware
      end

      # act
      store = config.store.build(config)

      stack = middleware_stack(store)
      expect(stack[stack.length - 2]).to be_a Test_Middleware
      expect(stack[stack.length - 1]).to be_a WCC::Contentful::Store::CDNAdapter
    end

    it 'wraps instrumentation around the top of the stack' do
      custom_store = double(
        index: nil,
        index?: true,
        find: nil,
        find_by: nil,
        find_all: []
      )

      config.store custom_store do
        use Test_Middleware
        use WCC::Contentful::Middleware::Store::CachingMiddleware
      end

      # act
      store = config.store.build(config)

      expect(store).to be_a WCC::Contentful::Store::InstrumentationMiddleware
      expect {
        store.find('abcd')
      }.to instrument('find.store.contentful.wcc').once
      expect {
        store.find_by(content_type: 'abcd')
      }.to instrument('find_by.store.contentful.wcc').once
      expect {
        store.find_all(content_type: 'abcd').first
      }.to instrument('find_all.store.contentful.wcc').once
      expect {
        store.index({ 'sys' => { 'type' => 'test', 'id' => 1 } })
      }.to instrument('index.store.contentful.wcc').once
    end
  end

  describe '#instrumentation_adapter' do
    it 'applies custom instrumentation adapter to the whole stack' do
      instrumentation = double('instrumentation')
      config.instrumentation_adapter = instrumentation

      stub_request(:get, /\/(entries|assets)\/test/)
        .to_return(status: 404)

      expect(ActiveSupport::Notifications).to_not receive(:instrument)
      expect(instrumentation).to receive(:instrument) { |_, _, &block| block.call }
        .at_least(:once)

      # act
      WCC::Contentful::Model.find('test')
    end
  end

  describe '#validate!' do
    it 'permits non-master environment combined with sync delivery strategy' do
      config.space = 'test_space'
      config.access_token = 'test_token'

      # good
      config.environment = ''
      config.store = :lazy_sync
      config.validate!

      config.store = :eager_sync
      config.validate!

      config.environment = 'staging'
      config.store = :direct
      config.validate!

      config.environment = 'staging'
      config.store = :lazy_sync
      config.validate!

      config.store = :eager_sync
      config.validate!
    end

    it 'errors when non-callable object given to webhook_jobs' do
      config.space = 'test_space'
      config.access_token = 'test_token'

      callable_class =
        Class.new {
          def call(evt)
          end
        }

      # good
      config.webhook_jobs << ->(e) {}
      config.webhook_jobs << proc {}
      config.webhook_jobs << callable_class.new

      config.validate!

      # bad
      expect {
        config.webhook_jobs = ['some string']
        config.validate!
      }.to raise_error(ArgumentError)

      expect {
        config.webhook_jobs = [callable_class]
        config.validate!
      }.to raise_error(ArgumentError)
    end
  end

  describe '#freeze' do
    subject(:config) {
      config = WCC::Contentful::Configuration.new
      config.space = 'test-space'
      config.access_token = 'test-at'
      config.app_url = 'test-app-url'
      config.management_token = 'test-mt'
      config.environment = 'test'
      config.default_locale = 'asdf'
      config.preview_token = 'test-pt'
      config.webhook_username = 'test-wh'
      config.webhook_password = 'test-wh-pword'
      config.webhook_jobs = [
        -> { 'one' },
        (WCC::Contentful::SyncEngine::Job if defined?(WCC::Contentful::SyncEngine::Job))
      ]
      config.store = :lazy_sync, ActiveSupport::Cache::MemoryStore.new
      config.connection = -> { 'test' }
      config
    }

    it { expect(config.frozen?).to be false }
    it { expect(config.freeze.frozen?).to be true }

    it 'returns an instance that has all the same readable attributes' do
      frozen = config.freeze

      WCC::Contentful::Configuration::ATTRIBUTES.each do |att|
        expect(frozen.send(att)).to eq(config.send(att))
      end
    end

    it 'does not allow setting any of the attributes' do
      frozen = config.freeze

      WCC::Contentful::Configuration::ATTRIBUTES.each do |att|
        expect {
          frozen.send("#{att}=", 'test')
        }.to raise_error(NoMethodError)
      end
    end

    it 'does not allow modifying hashes or arrays' do
      frozen = config.freeze

      %i[webhook_jobs].each do |att|
        expect {
          frozen.send(att) << 'test'
        }.to(
          raise_error(RuntimeError) do |e|
            expect(e.message).to eq("can't modify frozen Array")
          end
        )
      end
    end

    it 'does not freeze a Faraday Connection' do
      conn = double
      expect(conn).to_not receive(:freeze)
      config.connection = conn

      frozen = config.freeze

      expect(frozen.connection).to be conn
    end
  end

  def middleware_stack(store)
    stack = [store]
    while store = store.try(:store)
      stack << store
    end
    stack
  end
end

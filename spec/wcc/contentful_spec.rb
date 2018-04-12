# frozen_string_literal: true

RSpec.describe WCC::Contentful, :vcr do
  it 'has a version number' do
    expect(WCC::Contentful::VERSION).not_to be nil
  end

  let(:valid_contentful_access_token) { contentful_access_token }
  let(:valid_contentful_space_id) { contentful_space_id }
  let(:valid_contentful_default_locale) { 'en-US' }
  let(:valid_contentful_preview_token) { contentful_preview_token }
  let(:valid_contentful_preview_password) { contentful_preview_password }

  before do
    WCC::Contentful.configure do |config|
      config.access_token = valid_contentful_access_token
      config.space = valid_contentful_space_id
      config.content_delivery = :eager_sync
      config.environment = nil
    end
  end

  after(:each) do
    consts = WCC::Contentful::Model.all_models.map(&:to_s).uniq
    consts.each do |c|
      begin
        WCC::Contentful::Model.send(:remove_const, c.split(':').last)
      rescue StandardError => e
        warn e
      end
    end
    WCC::Contentful::Model.class_variable_get('@@registry').clear
  end

  describe '.init with preview token' do
    context 'with preview token' do
      before do
        WCC::Contentful.configure do |config|
          config.access_token = valid_contentful_access_token
          config.space = valid_contentful_space_id
          config.store = nil
          config.preview_token = valid_contentful_preview_token
          config.content_delivery = :direct
        end
      end

      it 'should populate models via Preview client' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :new_episodes
        ) do
          WCC::Contentful.init!

          # assert
          content_type = WCC::Contentful::Model::Redirect.content_type
          expect(content_type).to eq('redirect')
        end
      end

      it 'should find published content in Contentful' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :new_episodes
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_preview_token/published_redirect',
            record: :new_episodes
          ) do
            redirect = WCC::Contentful::Model::Redirect.find_by(slug: 'published-redirect')

            expect(redirect).to_not be_nil
            expect(redirect.url).to eq('https://watermark.formstack.com/forms/theporch')
          end
        end
      end

      it 'should not find draft content in Contentful if no preview password is given' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :new_episodes
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_preview_token/redirect_without_preview_password',
            record: :new_episodes
          ) do
            redirect = WCC::Contentful::Model::Redirect.find_by(slug: 'draft-redirect')

            expect(redirect).to be_nil
          end
        end
      end

      it 'should find draft content in Contentful if correct preview password is given' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :new_episodes
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_preview_token/redirect_with_preview_password',
            record: :new_episodes
          ) do
            redirect = WCC::Contentful::Model::Redirect.find_by(
              { slug: 'draft-redirect' },
              preview: valid_contentful_preview_password
            )

            expect(redirect).to_not be_nil
            expect(redirect.url).to eq('https://google.com')
          end
        end
      end
    end
  end

  describe '.configure' do
    context 'when passed VALID configuration arguments' do
      before do
        WCC::Contentful.configure do |config|
          config.access_token = valid_contentful_access_token
          config.space = valid_contentful_space_id
          config.default_locale = valid_contentful_default_locale
        end
      end

      it 'should return a Contentful config object populated with the valid values given' do
        config = WCC::Contentful.configuration

        expect(config.access_token).to eq(valid_contentful_access_token)
        expect(config.space).to eq(valid_contentful_space_id)
        expect(config.default_locale).to eq(valid_contentful_default_locale)
        expect(config.nil?).to eq(false)
      end

      it 'should set the Contentful client on the WCC::Contentful module' do
        client = WCC::Contentful.client

        expect(client).to be_a(WCC::Contentful::SimpleClient)
      end
    end

    context 'invalid config' do
      it 'should error when space is nil' do
        expect {
          WCC::Contentful.configure do |config|
            config.access_token = valid_contentful_access_token
            config.space = nil
          end
        }.to raise_error(ArgumentError)
      end

      it 'should error when access token is nil' do
        expect {
          WCC::Contentful.configure do |config|
            config.access_token = nil
            config.space = valid_contentful_space_id
          end
        }.to raise_error(ArgumentError)
      end

      it 'should error when trying to use sync with environments' do
        expect {
          WCC::Contentful.configure do |config|
            config.access_token = valid_contentful_access_token
            config.space = valid_contentful_space_id

            config.content_delivery = :eager_sync
            config.environment = 'specs'
          end
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.init' do
    before do
      allow(WCC::Contentful).to receive(:validate_models!)
    end

    it 'raises argument error if not configured' do
      WCC::Contentful.instance_variable_set('@configuration', nil)

      # act
      expect {
        WCC::Contentful.init!
      }.to raise_error(ArgumentError)
    end

    context 'without management token' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.access_token = valid_contentful_access_token
          config.space = valid_contentful_space_id
          config.management_token = nil
          config.default_locale = nil

          # rebuild store
          config.store = nil
          config.content_delivery = :eager_sync, :memory
        end
      end

      it 'should populate models via CDN client' do
        # act
        WCC::Contentful.init!

        # assert
        content_type = WCC::Contentful::Model::MenuButton.content_type
        expect(content_type).to eq('menuButton')
      end

      it 'should populate store via sync API' do
        # act
        WCC::Contentful.init!

        # assert
        page = WCC::Contentful::Model.find('1UojJt7YoMiemCq2mGGUmQ')
        expect(page).to_not be_nil
        expect(page).to be_a(WCC::Contentful::Model::Page)
        expect(page.slug).to eq('/conferences')

        expect(page.sections).to be_empty
      end
    end

    context 'with management token' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.management_token = contentful_management_token
          config.default_locale = nil

          # rebuild store
          config.store = nil
          config.content_delivery = :eager_sync, :memory
        end
      end

      it 'should populate models via Management API cache' do
        # act
        WCC::Contentful.init!

        # assert
        content_type = WCC::Contentful::Model::Page.content_type
        expect(content_type).to eq('page')
      end

      it 'should populate store via sync API' do
        # act
        WCC::Contentful.init!

        # assert
        asset = WCC::Contentful::Model::Asset.find('2zKTmej544IakmIqoEu0y8')
        expect(asset).to_not be_nil
        expect(asset).to be_a(WCC::Contentful::Model::Asset)
        expect(asset.file.fileName).to eq('favicon.ico')
      end
    end

    context 'with stored sync_token' do
      let(:empty) { JSON.parse(load_fixture('contentful/sync_empty.json')) }
      let(:store) { WCC::Contentful::Store::MemoryStore.new }

      before(:each) do
        store.set("sync:#{contentful_space_id}:token", 'testX')

        WCC::Contentful.configure do |config|
          config.management_token = contentful_management_token
          config.default_locale = nil
          config.store = store
        end
      end

      it 'continues from stored sync ID' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
          .with(query: hash_including('sync_token' => 'testX'))
          .to_return(body: empty.merge({ 'nextSyncUrl' =>
            "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=testY" }).to_json)

        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
          .with(query: hash_including('initial' => 'true'))
          .to_raise('Should not call sync with initial=true when a stored sync token exists')

        # act
        WCC::Contentful.init!

        # assert
        expect(WCC::Contentful.next_sync_token).to eq('testY')
      end
    end

    context 'content_delivery = direct' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.management_token = contentful_management_token
          config.store = nil
          config.content_delivery = :direct
        end
      end

      it 'builds out store using CDNAdapter' do
        # act
        WCC::Contentful.init!

        # assert
        expect(WCC::Contentful::Model.store).to be_a(WCC::Contentful::Store::CDNAdapter)

        page = WCC::Contentful::Model::Page.find('JhYhSfZPAOMqsaK8cYOUK')
        expect(page.title).to eq('Ministries')
      end
    end

    context 'content_delivery = lazy_sync' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.management_token = contentful_management_token
          config.store = nil
          config.content_delivery = :lazy_sync
        end
      end

      let(:side_menu) {
        <<~JSON
          {
            "sys": {
              "space": {
                "sys": {
                  "type": "Link",
                  "linkType": "Space",
                  "id": "#{contentful_space_id}"
                }
              },
              "id": "6y9DftpiYoA4YiKg2CgoUU",
              "type": "Entry",
              "createdAt": "2018-02-12T20:08:32.729Z",
              "updatedAt": "2018-02-12T20:08:32.729Z",
              "revision": 1,
              "contentType": {
                "sys": {
                  "type": "Link",
                  "linkType": "ContentType",
                  "id": "menu"
                }
              }
            },
            "fields": {
              "name": {
                "en-US": "Side Menu"
              },
              "items": {
                "en-US": [
                  {
                    "sys": {
                      "type": "Link",
                      "linkType": "Entry",
                      "id": "1IJEXB4AKEqQYEm4WuceG2"
                    }
                  }
                ]
              }
            }
          }
        JSON
      }

      let(:about_button) {
        <<~JSON
          {
            "sys": {
              "space": {
                "sys": {
                  "type": "Link",
                  "linkType": "Space",
                  "id": "#{contentful_space_id}"
                }
              },
              "id": "1IJEXB4AKEqQYEm4WuceG2",
              "type": "Entry",
              "createdAt": "2018-02-12T20:08:38.625Z",
              "updatedAt": "2018-02-12T20:08:38.625Z",
              "revision": 1,
              "contentType": {
                "sys": {
                  "type": "Link",
                  "linkType": "ContentType",
                  "id": "menuButton"
                }
              }
            },
            "fields": {
              "text": {
                "en-US": "About"
              },
              "link": {
                "en-US": {
                  "sys": {
                    "type": "Link",
                    "linkType": "Entry",
                    "id": "47PsST8EicKgWIWwK2AsW6"
                  }
                }
              }
            }
          }
        JSON
      }

      it 'should call out to CDN for first calls only' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
          '/entries/6y9DftpiYoA4YiKg2CgoUU')
          .with(query: hash_including({ locale: '*' }))
          .to_return(body: side_menu)
          .times(1)
          .then.to_raise('Should not hit the API a second time!')
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
          '/entries/1IJEXB4AKEqQYEm4WuceG2')
          .with(query: hash_including({ locale: '*' }))
          .to_return(body: about_button)
          .times(1)
          .then.to_raise('Should not hit the API a second time!')

        # act
        WCC::Contentful.init!
        menu = WCC::Contentful::Model::Menu.find('6y9DftpiYoA4YiKg2CgoUU')
        button = menu.items.first

        # assert
        expect(menu.name).to eq('Side Menu')
        expect(button.text).to eq('About')
        button2 = WCC::Contentful::Model::Menu.find('6y9DftpiYoA4YiKg2CgoUU').items.first
        expect(button2.text).to eq('About')
      end

      context 'with stored sync_token' do
        let(:empty) { JSON.parse(load_fixture('contentful/sync_empty.json')) }
        let(:store) { ActiveSupport::Cache::MemoryStore.new }

        before(:each) do
          store.write("sync:#{contentful_space_id}:token", 'testX')

          WCC::Contentful.configure do |config|
            config.management_token = contentful_management_token
            config.default_locale = nil

            # rebuild store
            config.store = nil
            config.content_delivery = :lazy_sync, store
          end
        end

        it 'continues from stored sync ID' do
          stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
            .with(query: hash_including('sync_token' => 'testX'))
            .to_return(body: empty.merge({ 'nextSyncUrl' =>
              "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=testY" })
              .to_json)

          stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
            .with(query: hash_including('initial' => 'true'))
            .to_raise('Should not call sync with initial=true when a stored sync token exists')

          # act
          WCC::Contentful.init!

          # assert
          expect(WCC::Contentful.next_sync_token).to eq('testY')
        end
      end
    end
  end

  describe '.validate_models!' do
    let(:content_types) {
      raw = JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
      raw['items']
    }
    let(:models_dir) {
      File.dirname(__FILE__) + '/../../lib/wcc/contentful/model'
    }

    it 'validates successfully if all types present' do
      indexer =
        WCC::Contentful::ContentTypeIndexer.new.tap do |ixr|
          content_types.each { |type| ixr.index(type) }
        end
      types = indexer.types
      WCC::Contentful::ModelBuilder.new(types).build_models
      WCC::Contentful.instance_variable_set('@content_types', content_types)
      Dir["#{models_dir}/*.rb"].each { |file| load file }

      # act
      expect {
        WCC::Contentful.validate_models!
      }.to_not raise_error
    end

    it 'fails validation if menus not present' do
      all_but_menu = content_types.reject { |ct| ct.dig('sys', 'id') == 'menu' }
      indexer =
        WCC::Contentful::ContentTypeIndexer.new.tap do |ixr|
          all_but_menu.each { |type| ixr.index(type) }
        end
      types = indexer.types
      WCC::Contentful::ModelBuilder.new(types).build_models
      WCC::Contentful.instance_variable_set('@content_types', all_but_menu)

      load "#{models_dir}/menu.rb"

      # act
      expect {
        WCC::Contentful.validate_models!
      }.to raise_error(WCC::Contentful::ValidationError)
    end
  end

  describe '.sync!' do
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
        config.access_token = valid_contentful_access_token
        config.space = valid_contentful_space_id
        config.management_token = nil
        config.default_locale = nil

        # rebuild store
        config.store = nil
        config.content_delivery = :eager_sync
      end

      WCC::Contentful.init!
    end

    context 'when no ID given' do
      it 'does nothing if no sync data available' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
          .with(query: hash_including('sync_token' => 'FwqZm...'))
          .to_return(body: empty.merge({ 'nextSyncUrl' =>
            "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=test" }).to_json)

        expect(WCC::Contentful.store).to receive(:set)
          .with("sync:#{contentful_space_id}:token", 'test')
        expect(WCC::Contentful.store).to_not receive(:index)

        # act
        synced = WCC::Contentful.sync!

        # assert
        expect(synced).to eq('test')
        expect(WCC::Contentful.next_sync_token).to eq('test')
      end

      it 'updates the store with the latest data' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
          .with(query: hash_including('sync_token' => 'FwqZm...'))
          .to_return(body: next_sync.merge({ 'nextSyncUrl' =>
            "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=test1" }).to_json)

        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
          .with(query: hash_including('sync_token' => 'test1'))
          .to_return(body: empty.merge({ 'nextSyncUrl' =>
            "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=test2" }).to_json)

        items = next_sync['items']

        expect(WCC::Contentful.store).to receive(:set)
          .with("sync:#{contentful_space_id}:token", 'test2')
        expect(WCC::Contentful.store).to receive(:index)
          .exactly(items.count).times

        # act
        WCC::Contentful.sync!

        # assert
        expect(WCC::Contentful.next_sync_token).to eq('test2')
      end
    end

    context 'when ID given' do
      before do
        # ensure rails doesn't exist - because if it does, `sync!` drops a job
        # instead of raising a sync error
        if defined?(Rails)
          @tmp_rails = Rails
          Object.send(:remove_const, 'Rails')
        end
      end

      after do
        Object.const_set('Rails', @tmp_rails) if @tmp_rails
      end

      it 'raises a sync error if the ID does not come back' do
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
        }.to raise_error(WCC::Contentful::SyncError)
      end

      it 'does not drop a job if the ID comes back in the sync' do
        require 'active_job'

        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
          .with(query: hash_including('sync_token' => 'FwqZm...'))
          .to_return(body: next_sync.merge({ 'nextSyncUrl' =>
            "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=test1" }).to_json)

        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync")
          .with(query: hash_including('sync_token' => 'test1'))
          .to_return(body: empty.merge({ 'nextSyncUrl' =>
            "https://cdn.contentful.com/spaces/#{contentful_space_id}/sync?sync_token=test2" }).to_json)

        expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
        expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)

        # act
        WCC::Contentful.sync!(up_to_id: '1EjBdAgOOgAQKAggQoY2as')
      end
    end
  end
end

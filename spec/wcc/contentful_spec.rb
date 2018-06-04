# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful, :vcr do
  it 'has a version number' do
    expect(WCC::Contentful::VERSION).not_to be nil
  end

  let(:valid_contentful_access_token) { contentful_access_token }
  let(:valid_contentful_space_id) { contentful_space_id }
  let(:valid_contentful_default_locale) { 'en-US' }
  let(:valid_contentful_preview_token) { contentful_preview_token }

  before do
    WCC::Contentful.configure do |config|
      config.management_token = nil
      config.access_token = valid_contentful_access_token
      config.space = valid_contentful_space_id
      config.content_delivery = :eager_sync
      config.environment = nil
    end
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

      it 'should find published content in Contentful if preview is set to true' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :none
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_preview_token/published_redirect_preview_true',
            record: :none
          ) do
            redirect = WCC::Contentful::Model::Redirect.find_by(
              slug: 'published-redirect',
              options: { preview: true }
            )

            expect(redirect).to_not be_nil
            expect(redirect.url).to eq('https://watermark.formstack.com/forms/theporch')
          end
        end
      end

      it 'should find published content in Contentful if preview is set to false' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :none
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_preview_token/published_redirect_preview_false',
            record: :none
          ) do
            redirect = WCC::Contentful::Model::Redirect.find_by(
              slug: 'published-redirect',
              options: { preview: false }
            )

            expect(redirect).to_not be_nil
            expect(redirect.url).to eq('https://watermark.formstack.com/forms/theporch')
          end
        end
      end

      it 'should not find draft content in Contentful if preview is set to false' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :none
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_preview_token/draft_redirect_preview_false',
            record: :none
          ) do
            redirect = WCC::Contentful::Model::Redirect.find_by(
              slug: 'draft-redirect',
              options: { preview: false }
            )

            expect(redirect).to be_nil
          end
        end
      end

      it 'should find draft content in Contentful if preview is set to true' do
        # act
        VCR.use_cassette(
          'WCC_Contentful/_init/with_preview_token/init_with_preview_token',
          record: :none
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_preview_token/draft_redirect_preview_true',
            record: :none
          ) do
            redirect = WCC::Contentful::Model::Redirect.find_by(
              slug: 'draft-redirect',
              options: { preview: true }
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

      it 'should error when trying to use preview api' do
        VCR.use_cassette(
          'WCC_Contentful/_init/content_delivery_lazy_sync/should_call_out_to_CDN_for_first_calls_only',
          record: :none
        ) do
          WCC::Contentful.init!

          VCR.use_cassette(
            'WCC_Contentful/_init/with_management_token/published_redirect_preview_true',
            record: :new_episodes
          ) do
            expect {
              WCC::Contentful::Model::Menu.find_by(
                id: 'menuId',
                options: { preview: true }
              )
            }.to raise_error(ArgumentError)
          end
        end
      end

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
end

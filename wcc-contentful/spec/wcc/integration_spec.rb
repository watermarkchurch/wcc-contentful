# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Full Stack Integration' do
  before do
    WCC::Contentful.configure do |config|
      config.management_token = contentful_management_token
      config.access_token = contentful_access_token
      config.space = contentful_space_id
      config.preview_token = contentful_preview_token
      config.environment = nil
      config.update_schema_file = :never
    end
  end

  context 'Sync Strategy: lazy_sync' do
    before do
      WCC::Contentful.configure do |config|
        config.store = :lazy_sync
      end
    end

    it 'fetches an entry with broken includes' do
      stub_request(:get, /https:\/\/api.contentful.com\/spaces\/.+\/content_types/)
        .to_return(body: load_fixture('contentful/content_types_mgmt_api.json'))

      WCC::Contentful.init!

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          'fields.slug' => '/ministries/merge',
          'include' => '3'
        }))
        .to_return(body: load_fixture('contentful/merge_query.json'))

      WCC::Contentful::Model::Page.find_by(slug: '/ministries/merge', options: { include: 3 })
    end
  end

  describe 'Locale support' do
    context 'Sync Strategy: Eager Sync' do
      before do
        WCC::Contentful.configure do |config|
          config.default_locale = 'en-US'
          config.store = :eager_sync
          config.schema_file = path_to_fixture('contentful/simple_space_content_types.json')
          config.update_schema_file = :never
        end

        stub_request(:get, /https:\/\/cdn.contentful.com\/spaces\/.+\/sync/)
          .with(query: {
            'initial' => 'true'
          })
          .to_return(body: load_fixture('contentful/simple_space_sync.json'))

        stub_request(:get, /https:\/\/cdn.contentful.com\/spaces\/.+\/sync/)
          .with(query: {
            'sync_token' => 'FwqZm...'
          })
          .to_return(body: load_fixture('contentful/sync_empty.json'))

        WCC::Contentful.init!

        WCC::Contentful::Services.instance.sync_engine.next
      end

      it 'fetches page in default locale' do
        page = WCC::Contentful::Model.find('6hjxaS8Ov2m2gS0swB1kW0')

        expect(page.sys.locale).to eq('en-US')
        expect(page.title).to eq('Homepage')
        expect(page.slug).to eq('/')

        expect(page.sections[0].title).to eq('Homepage Hero')
        expect(page.sections[0].subtitle).to eq('This is the Homepage')
        expect(page.sections[0].hero_image.file.url).to end_with('worship-stage.webp')

        expect(page.sections[1].internal_title).to eq('Homepage block text')
        expect(page.sections[1].body.content[0].content[0].value).to eq('Lorem Ipsum')
      end

      it 'fetches page with locale option' do
        page = WCC::Contentful::Model.find('6hjxaS8Ov2m2gS0swB1kW0',
          options: { locale: 'es-US' })

        expect(page.sys.locale).to eq('es-US')
        expect(page.title).to eq('Homepage')
        expect(page.slug).to eq('/')

        expect(page.sections[0].title).to eq('Homepage Hero')
        expect(page.sections[0].subtitle).to eq('Esta es la página principal')
        expect(page.sections[0].hero_image.title).to eq('la imagen de página principal')
        expect(page.sections[0].hero_image.file.url).to end_with('albania.jpg')

        expect(page.sections[1].internal_title).to eq('Homepage block text')
        expect(page.sections[1].body.content[0].content[0].value).to eq(
          'El ingenioso hidalgo don Quijote de la Mancha'
        )
      end
    end
  end
end

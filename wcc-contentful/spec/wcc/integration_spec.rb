# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Full Stack Integration' do
  context 'Sync Strategy: lazy_sync' do
    before do
      WCC::Contentful.configure do |config|
        config.management_token = contentful_management_token
        config.access_token = contentful_access_token
        config.space = contentful_space_id
        config.preview_token = contentful_preview_token
        config.store = :lazy_sync
        config.environment = nil
        config.update_schema_file = :never
      end

      stub_request(:get, /https:\/\/api.contentful.com\/spaces\/.+\/content_types/)
        .to_return(body: load_fixture('contentful/content_types_mgmt_api.json'))
    end

    it 'fetches an entry with broken includes' do
      WCC::Contentful.init!

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          'locale' => '*',
          'fields.slug.en-US' => '/ministries/merge',
          'include' => '3'
        }))
        .to_return(body: load_fixture('contentful/merge_query.json'))

      WCC::Contentful::Model::Page.find_by(slug: '/ministries/merge', options: { locale: '*', include: 3 })
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Full Stack Integration', :vcr do
  context 'Sync Strategy: lazy_sync' do
    before do
      WCC::Contentful.configure do |config|
        config.management_token = contentful_management_token
        config.access_token = contentful_access_token
        config.space = contentful_space_id
        config.preview_token = contentful_preview_token
        config.content_delivery = :lazy_sync
        config.environment = nil
      end
    end

    it 'fetches an entry with broken includes' do
      stub_content_types('page')
      WCC::Contentful.init!

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          'fields.slug.en-US' => '/ministries/merge',
          'include' => '3'
        }))
        .to_return(body: load_fixture('contentful/merge_query.json'))

      WCC::Contentful::Model::Page.find_by(slug: '/ministries/merge', options: { include: 3 })
    end
  end

  def stub_content_types(*content_types)
    resp = {
      sys: { type: 'Array' },
      total: content_types.length,
      skip: 0,
      limit: 100,
      items: content_types.map do |fixture|
        JSON.parse(load_fixture(File.join('contentful', 'content_types', "#{fixture}.json")))
      end
    }
    stub_request(:get, "https://api.contentful.com/spaces/#{contentful_space_id}/content_types")
      .with(query: hash_including({ 'limit' => '1000' }))
      .to_return(body: resp.to_json)
  end
end

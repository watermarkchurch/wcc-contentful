# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::WebhookController, type: :request do
  describe 'receive' do
    let!(:good_headers) {
      {
        'Authorization' => basic_auth('tester1', 'password1'),
        'Content-Type' => 'application/vnd.contentful.management.v1+json',
        'x-contentful-topic' => 'ContentManagement.Entry.publish'
      }
    }

    let(:body) {
      load_fixture('contentful/contentful_published_blog.json')
    }

    before do
      WCC::Contentful.configure do |config|
        config.webhook_username = 'tester1'
        config.webhook_password = 'password1'
        config.space = contentful_space_id
        config.access_token = contentful_access_token

        # required in order to trigger SyncEngine::Job
        config.content_delivery = :eager_sync, :memory
      end
    end

    it 'denies requests without HTTP BASIC auth' do
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers.slice('Content-Type')

      # assert
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies requests with bad HTTP BASIC auth' do
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers.merge('Authorization' => basic_auth('tester1', 'badpasswd'))

      # assert
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies requests with bad content type' do
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers.slice('Authorization')

      # assert
      expect(response).to have_http_status(:not_acceptable)
      expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
    end

    it 'denies requests not conforming to contentful object structure' do
      post '/wcc/contentful/webhook/receive',
        params: '{}',
        headers: good_headers

      # assert
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 204 no content on success' do
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers

      # assert
      expect(response).to have_http_status(:no_content)
    end

    it 'immediately updates the store on success' do
      # expect
      store = double(fetch: nil, write: nil)
      expect(store).to receive(:index)
        .with(hash_including(JSON.parse(body)))
      allow(WCC::Contentful::Services.instance)
        .to receive(:store)
        .and_return(store)

      # act
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers
    end

    it 'emits events on success' do
      events = []
      parsed_body = JSON.parse(body)

      WCC::Contentful::WebhookController.subscribe(
        proc { |event| events << event },
        with: :call
      )

      # act
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers

      # assert
      expect(events.length).to eq(1)
      expect(events[0]).to be_a WCC::Contentful::Event::Entry
      expect(events[0].to_h).to eq(parsed_body)
      expect(events[0].source).to eq(controller)
    end

    it 'does not update store or emit event when environment is wrong' do
      store = double(fetch: nil, write: nil)
      allow(WCC::Contentful::Services.instance)
        .to receive(:store)
        .and_return(store)

      events = []
      WCC::Contentful::WebhookController.subscribe(
        proc { |event| events << event },
        with: :call
      )

      expect(store).to_not receive(:index)

      body = load_fixture('contentful/contentful_published_page_staging.json')

      # act
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers

      # assert
      expect(events.length).to eq(0)
    end

    def basic_auth(user, password)
      ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
    end
  end
end

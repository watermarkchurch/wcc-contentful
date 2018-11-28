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
      store = double
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

    it 'runs a sync on success' do
      expect(WCC::Contentful::SyncEngine::Job).to receive(:perform_later)
        .with(hash_including(JSON.parse(body)))

      # act
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers

      # assert
      expect(response).to have_http_status(:no_content)
    end

    it 'runs a sync even in master environment' do
      WCC::Contentful.configure do |config|
        config.environment = 'staging'
      end

      # expect
      expect(WCC::Contentful::SyncEngine::Job).to receive(:perform_later)

      # act
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers

      # assert
      expect(response).to have_http_status(:no_content)
    end

    it 'runs configured jobs on success' do
      events = []
      my_job = double(perform_later: nil)
      jobs = [
        ->(evt) { events.push(evt) },
        proc { |evt| events.push(evt) },
        my_job
      ]
      expect(WCC::Contentful.configuration).to receive(:webhook_jobs)
        .and_return(jobs)

      parsed_body = JSON.parse(body)
      expect(my_job).to receive(:perform_later)
        .with(hash_including(parsed_body))

      # act
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers

      # assert
      expect(events.length).to eq(2)
      expect(events[0]).to eq(parsed_body)
      expect(events[1]).to eq(parsed_body)
    end

    it 'continues running jobs even if one fails' do
      events = []
      jobs = [
        ->(_evt) { raise ArgumentError, 'boom' },
        proc { |evt| events.push(evt) }
      ]
      expect(WCC::Contentful.configuration).to receive(:webhook_jobs)
        .and_return(jobs)

      # act
      post '/wcc/contentful/webhook/receive',
        params: body,
        headers: good_headers

      # assert
      expect(events.length).to eq(1)
      expect(events[0]).to eq(JSON.parse(body))
    end

    def basic_auth(user, password)
      ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
    end
  end
end

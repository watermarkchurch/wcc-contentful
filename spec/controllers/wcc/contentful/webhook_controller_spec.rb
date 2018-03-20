# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::WebhookController, type: :controller do
  routes { WCC::Contentful::Engine.routes }

  render_views

  describe 'receive' do
    let!(:good_headers) {
      {
        'Authorization': basic_auth('tester1', 'password1'),
        'Content-Type': 'application/vnd.contentful.management.v1+json',
        'x-contentful-topic': 'ContentManagement.Entry.publish'
      }
    }

    before do
      WCC::Contentful.configure do |config|
        config.webhook_username = 'tester1'
        config.webhook_password = 'password1'
      end
      allow(WCC::Contentful).to receive(:sync!)
    end

    it 'denies requests without HTTP BASIC auth' do
      request.headers[:'Content-Type'] = 'application/vnd.contentful.management.v1+json'
      post :receive,
        body: '{}',
        format: :json

      # assert
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies requests with bad HTTP BASIC auth' do
      request.headers.merge!(
        'Authorization': basic_auth('tester1', 'badpasswd'),
        'Content-Type': 'application/vnd.contentful.management.v1+json'
      )
      post :receive, body: '{}'

      # assert
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies requests with bad content type' do
      request.headers[:Authorization] = basic_auth('tester1', 'password1')
      post :receive, body: '{}'

      # assert
      expect(response).to have_http_status(:not_acceptable)
    end

    it 'returns 204 no content on success' do
      request.headers.merge!(
        'Authorization': basic_auth('tester1', 'password1'),
        'Content-Type': 'application/vnd.contentful.management.v1+json'
      )
      post :receive,
        body: '{}'

      # assert
      expect(response).to have_http_status(:no_content)
    end

    it 'runs a sync on success' do
      request.headers.merge!(
        'Authorization': basic_auth('tester1', 'password1'),
        'Content-Type': 'application/vnd.contentful.management.v1+json',
        'x-contentful-topic': 'ContentManagement.Entry.unpublish'
      )
      body = load_fixture('contentful/contentful_published_blog.json')

      expect(WCC::Contentful).to receive(:sync!)
        .with(up_to_id: 'rYhUgNF6k8iU2mI84gQOQ')

      # act
      post :receive,
        body: body

      # assert
      expect(response).to have_http_status(:no_content)
    end

    def basic_auth(user, password)
      ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
    end
  end
end

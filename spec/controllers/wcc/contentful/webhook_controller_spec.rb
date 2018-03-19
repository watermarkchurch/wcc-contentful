# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::WebhookController, type: :controller do
  routes { WCC::Contentful::Engine.routes }

  render_views

  describe 'receive' do
    let!(:good_headers) {
      ENV['CONTENTFUL_BLOG_WEBHOOK_USERNAME'] = 'tester1'
      ENV['CONTENTFUL_BLOG_WEBHOOK_PASSWORD'] = 'password1'
      {
        'Authorization': basic_auth('tester1', 'password1'),
        'Content-Type': 'application/vnd.contentful.management.v1+json',
        'x-contentful-topic': 'ContentManagement.Entry.publish'
      }
    }

    it 'denies requests without HTTP BASIC auth' do
      post :receive,
        body: '{}',
        format: :json

      # assert
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies requests with bad HTTP BASIC auth' do
      request.headers['Authorization'] = basic_auth('tester1', 'badpasswd')
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
        .with('rYhUgNF6k8iU2mI84gQOQ')

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

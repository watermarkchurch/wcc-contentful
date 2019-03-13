# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::WebhookEnableJob, type: :job do
  ActiveJob::Base.queue_adapter = :test

  subject(:job) { described_class.new }

  describe '#enable_webhook' do
    it 'bails if webhook already exists' do
      response = double(items: [{
        'name' => 'test webhook',
        'url' => 'https://test.url/webhook/receive'
      }])
      client = double(webhook_definitions: response)

      # act
      job.enable_webhook(client,
        app_url: 'https://test.url')

      # assert
      # client should not receive a "post" message.
    end

    it 'posts webhook to app url if necessary' do
      response = double(items: [])
      client = double(webhook_definitions: response)

      expect(client).to receive(:post_webhook_definition)
        .with(hash_including({
          'url' => 'https://test.url/webhook/receive',
            'topics' => [
              '*.publish',
              '*.unpublish'
            ]
        }))
        .and_return(double(raw: {}))

      # act
      job.enable_webhook(client,
        app_url: 'https://test.url/')
    end

    it 'posts webhook with auth if auth given' do
      response = double(items: [])
      client = double(webhook_definitions: response)

      expect(client).to receive(:post_webhook_definition)
        .with(hash_including({
          'url' => 'https://test.url/webhook/receive',
          'httpBasicUsername' => 'testuser',
          'httpBasicPassword' => 'testpw'
        }))
        .and_return(double(raw: {}))

      # act
      job.enable_webhook(client,
        app_url: 'https://test.url/',
        webhook_username: 'testuser',
        webhook_password: 'testpw')
    end

    it 'posts with environment ID filter if environment given' do
      config = double(environment: 'testtest')
      allow(WCC::Contentful).to receive(:configuration)
        .and_return(config)

      response = double(items: [])
      client = double(webhook_definitions: response)

      expect(client).to receive(:post_webhook_definition)
        .with(hash_including({
          'filters' => [
            {
              'equals' => [
                { 'doc' => 'sys.environment.sys.id' },
                'testtest'
              ]
            }
          ]
        }))
        .and_return(double(raw: {}))

      # act
      job.enable_webhook(client,
        app_url: 'https://test.url/')
    end
  end

  describe '#perform' do
    it 'passes client to #enable_webhook' do
      expect(job).to receive(:enable_webhook) do |client|
        expect(client).to be_a WCC::Contentful::SimpleClient::Management
      end

      # act
      job.perform({
        space: 'testspace',
        management_token: 'testtoken'
      })
    end
  end
end

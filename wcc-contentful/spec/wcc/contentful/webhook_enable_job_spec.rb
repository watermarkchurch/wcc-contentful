# frozen_string_literal: true

require 'job_helper'

require 'wcc/contentful/webhook_enable_job'

RSpec.describe 'WCC::Contentful::WebhookEnableJob', type: :job do
  subject(:job) {
    require_relative '../../../../app/jobs/wcc/contentful/webhook_enable_job'
    WCC::Contentful::WebhookEnableJob.new
  }

  describe '#enable_webhook' do
    it 'bails if webhook already exists' do
      response = double(items: [
                          {
                            'name' => 'test webhook',
                            'url' => 'https://test.url/webhook/receive'
                          }
                        ])
      client = double(webhook_definitions: response)

      # act
      job.enable_webhook(client,
        receive_url: 'https://test.url/webhook/receive')

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
        receive_url: 'https://test.url/webhook/receive')
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
        receive_url: 'https://test.url/webhook/receive',
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
        receive_url: 'https://test.url/webhook/receive')
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

    it 'gets default client params from WCC::Contentful.configuration' do
      defaults = {
        management_token: 'testtoken',
        app_url: 'http://testurl',
        space: 'testspace',
        environment: 'testenv',
        connection: :typhoeus,
        webhook_username: 'testwebhookusername',
        webhook_password: 'testwebhookpassword'
      }

      allow(WCC::Contentful).to receive(:configuration)
        .and_return(double(**defaults))

      expect(job).to receive(:enable_webhook) do |client|
        expect(client).to be_a WCC::Contentful::SimpleClient::Management

        options = client.instance_variable_get('@options')
        expect(client.space).to eq('testspace')
        expect(client.instance_variable_get('@access_token')).to eq('testtoken')
        expect(options[:connection]).to eq(:typhoeus)
      end

      # act
      job.perform
    end

    it 'invokes #post_webhook_definition with args' do
      body = nil
      allow_any_instance_of(WCC::Contentful::SimpleClient::Management)
        .to receive(:webhook_definitions)
        .and_return(double(items: []))
      expect_any_instance_of(WCC::Contentful::SimpleClient::Management)
        .to receive(:post_webhook_definition) do |_instance, b|
          body = b
          double(raw: {})
        end
      allow(WCC::Contentful).to receive(:configuration)
        .and_return(instance_double(WCC::Contentful::Configuration,
          space: 'testspace',
          management_token: 'testtoken',
          app_url: 'https://test.url',
          environment: 'master',
          connection: nil,
          webhook_username: nil,
          webhook_password: nil))

      # act
      job.perform({
        receive_url: 'https://test.url/webhook/receive',
        webhook_username: 'testuser',
        webhook_password: 'testpw'
      })

      # assert
      expect(body).to include({
        'name' => 'WCC::Contentful webhook',
        'url' => 'https://test.url/webhook/receive',
        'httpBasicUsername' => 'testuser',
        'httpBasicPassword' => 'testpw'
      })
    end
  end
end

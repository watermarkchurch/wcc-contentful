# frozen_string_literal: true

require 'active_job'

module WCC::Contentful
  class WebhookEnableJob < ActiveJob::Base
    self.queue_adapter = :async
    queue_as :default

    def perform(args)
      client = WCC::Contentful::SimpleClient::Management.new(
        args
      )
      enable_webhook(client, args)
    end

    def enable_webhook(client, app_url:, webhook_username: nil, webhook_password: nil)
      webhook = client.webhook_definitions.items.find { |w| w['url']&.include?(app_url) }
      return if webhook

      body = {
        'name' => 'WCC::Contentful webhook',
        'url' => URI.join(app_url, 'webhook/receive').to_s,
        'topics' => [
          '*.publish',
          '*.unpublish'
        ]
      }
      body['httpBasicUsername'] = webhook_username if webhook_username.present?
      body['httpBasicPassword'] = webhook_password if webhook_password.present?

      client.post_webhook_definition(body)
    end
  end
end

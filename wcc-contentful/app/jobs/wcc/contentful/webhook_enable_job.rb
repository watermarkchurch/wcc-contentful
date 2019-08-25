# typed: true
# frozen_string_literal: true

require 'active_job'

module WCC::Contentful
  class WebhookEnableJob < ActiveJob::Base
    self.queue_adapter = :async
    queue_as :default

    def perform(args = {})
      args = default_configuration.merge!(args)

      client = WCC::Contentful::SimpleClient::Management.new(
        args
      )
      enable_webhook(client, args.slice(:app_url, :webhook_username, :webhook_password))
    end

    def enable_webhook(client, app_url:, webhook_username: nil, webhook_password: nil)
      expected_url = URI.join(app_url, 'webhook/receive').to_s
      webhook = client.webhook_definitions.items.find { |w| w['url'] == expected_url }
      logger.debug "existing webhook: #{webhook.inspect}" if webhook
      return if webhook

      body = {
        'name' => 'WCC::Contentful webhook',
        'url' => expected_url,
        'topics' => [
          '*.publish',
          '*.unpublish'
        ],
        'filters' => webhook_filters
      }
      body['httpBasicUsername'] = webhook_username if webhook_username.present?
      body['httpBasicPassword'] = webhook_password if webhook_password.present?

      begin
        resp = client.post_webhook_definition(body)
        logger.info "Created webhook: #{resp.raw.dig('sys', 'id')}"
      rescue WCC::Contentful::SimpleClient::ApiError => e
        logger.error "#{e.response.code}: #{e.response.raw}" if e.response
        raise
      end
    end

    private

    def default_configuration
      return {} unless config = WCC::Contentful&.configuration

      {
        management_token: config.management_token,
        app_url: config.app_url,
        space: config.space,
        environment: config.environment,
        default_locale: config.default_locale,
        adapter: config.http_adapter,
        webhook_username: config.webhook_username,
        webhook_password: config.webhook_password
      }
    end

    def webhook_filters
      filters = []

      if (environment_id = WCC::Contentful.configuration&.environment).present?
        filters << {
          'equals' => [
            { 'doc' => 'sys.environment.sys.id' },
            environment_id
          ]
        }
      end
      filters
    end
  end
end

# frozen_string_literal: true

module WCC::Contentful
  class Engine < ::Rails::Engine
    initializer 'enable webhook' do
      config = WCC::Contentful.configuration
      next unless config&.management_token.present?
      next unless config.app_url.present?

      if Rails.env.production?
        WebhookEnableJob.set(wait: 10.seconds).perform_later(
          management_token: config.management_token,
          app_url: config.app_url,
          space: config.space,
          environment: config.environment,
          default_locale: config.default_locale,
          adapter: config.http_adapter,
          webhook_username: config.webhook_username,
          webhook_password: config.webhook_password
        )
      end
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end
  end
end

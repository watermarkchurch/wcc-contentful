# frozen_string_literal: true

module WCC::Contentful
  class Engine < ::Rails::Engine
    initializer 'enable webhook' do
      config = WCC::Contentful.configuration

      jobs = []
      if WCC::Contentful::Services.instance.sync_engine&.should_sync?
        jobs << WCC::Contentful::SyncEngine::Job
      end
      jobs.push(*WCC::Contentful.configuration.webhook_jobs)

      jobs.each do |job|
        puts "subscribe to #{job.inspect}"
        WCC::Contentful::WebhookController.subscribe(
          ->(event) do
            begin
              if job.respond_to?(:perform_later)
                job.perform_later(event.to_h)
              else
                Rails.logger.error "Misconfigured webhook job: #{job} does not respond to " \
                  ':perform_later'
              end
            rescue StandardError => e
              warn "Error in job #{job}: #{e}"
              Rails.logger.error "Error in job #{job}: #{e}"
            end
          end,
          with: :call
        )
      end

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

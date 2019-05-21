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

      WebhookEnableJob.set(wait: 10.seconds).perform_later if Rails.env.production?
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end

    # Clear the model registry to allow dev reloads to work properly
    # https://api.rubyonrails.org/classes/Rails/Railtie/Configuration.html#method-i-to_prepare
    config.to_prepare do
      WCC::Contentful::Model.clear_registry
    end
  end
end

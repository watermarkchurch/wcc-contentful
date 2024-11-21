# frozen_string_literal: true

module WCC::Contentful
  class Engine < ::Rails::Engine
    initializer 'enable webhook' do |app|
      app.config.to_prepare do
        config = WCC::Contentful.configuration

        jobs = []
        jobs << WCC::Contentful::SyncEngine::Job if WCC::Contentful::Services.instance.sync_engine&.should_sync?
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

        if defined?(WCC::Contentful::WebhookEnableJob)
          WCC::Contentful::WebhookEnableJob.set(wait: 10.seconds).perform_later if Rails.env.production?
        else
          Rails.logger.error 'ActiveJob is not defined, webhook enable job will not run'
        end
      end
    end

    initializer 'wcc-contentful.deprecations' do |app|
      app.deprecators[:wcc_contentful] = WCC::Contentful.deprecator if app.respond_to?(:deprecators)
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end

    # Clear the model registry to allow dev reloads to work properly
    # https://api.rubyonrails.org/classes/Rails/Railtie/Configuration.html#method-i-to_prepare
    config.to_prepare do
      WCC::Contentful::Model.reload!
    end
  end
end

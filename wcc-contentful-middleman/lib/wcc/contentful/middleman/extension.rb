# frozen_string_literal: true

class WCC::Contentful::Middleman::Extension < ::Middleman::Extension
  option :space,
    ENV['CONTENTFUL_SPACE_ID'],
    "Set the Contentful space ID (defaults to ENV['CONTENTFUL_SPACE_ID'])"
  option :access_token,
    ENV['CONTENTFUL_ACCESS_TOKEN'],
    "Set the Contentful CDN access key (defaults to ENV['CONTENTFUL_ACCESS_TOKEN'])"
  option :management_token,
    ENV['CONTENTFUL_MANAGEMENT_TOKEN'],
    "Set the Contentful API access token (defaults to ENV['CONTENTFUL_MANAGEMENT_TOKEN'])"
  option :preview_token,
    ENV['CONTENTFUL_PREVIEW_TOKEN'],
    "Set the Contentful Preview access token (defaults to ENV['CONTENTFUL_PREVIEW_TOKEN'])"
  option :environment,
    ENV['CONTENTFUL_ENVIRONMENT'],
    "Set the Contentful environment (defaults to ENV['CONTENTFUL_ENVIRONMENT'])"

  def initialize(app, options_hash = {}, &block)
    # don't pass block to super b/c we use it to configure WCC::Contentful
    super(app, options_hash) {}

    # Require libraries only when activated
    require 'wcc/contentful'

    # set up your extension
    return if WCC::Contentful.initialized

    WCC::Contentful.configure do |config|
      config.store :eager_sync, :memory

      options.to_h.each do |(k, v)|
        config.public_send("#{k}=", v) if config.respond_to?("#{k}=")
      end

      instance_exec(config, &block) if block_given?
    end

    WCC::Contentful.init!
    model_glob = File.join(Middleman::Application.root, 'lib/models/**/*.rb')
    Dir[model_glob].sort.each { |f| require f }

    # Sync the latest data from Contentful
    WCC::Contentful::Services.instance.sync_engine&.next
  end

  # A Sitemap Manipulator
  # def manipulate_resource_list(resources)
  # end

  # helpers do
  #   def a_helper
  #   end
  # end
end

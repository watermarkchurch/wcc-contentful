# frozen_string_literal: true

class WCC::Contentful::Middleman::Extension < ::Middleman::Extension
  option :space,
    ENV.fetch('CONTENTFUL_SPACE_ID', nil),
    "Set the Contentful space ID (defaults to ENV['CONTENTFUL_SPACE_ID'])"
  option :access_token,
    ENV.fetch('CONTENTFUL_ACCESS_TOKEN', nil),
    "Set the Contentful CDN access key (defaults to ENV['CONTENTFUL_ACCESS_TOKEN'])"
  option :management_token,
    ENV.fetch('CONTENTFUL_MANAGEMENT_TOKEN', nil),
    "Set the Contentful API access token (defaults to ENV['CONTENTFUL_MANAGEMENT_TOKEN'])"
  option :preview_token,
    ENV.fetch('CONTENTFUL_PREVIEW_TOKEN', nil),
    "Set the Contentful Preview access token (defaults to ENV['CONTENTFUL_PREVIEW_TOKEN'])"
  option :environment,
    ENV.fetch('CONTENTFUL_ENVIRONMENT', nil),
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

  # helpers do
  #   def a_helper
  #   end
  # end

  def ready
    # resync every page load in development & test mode only
    app.use ContentfulSyncUpdate if app.server?
  end

  # Rack app that advances the sync engine whenever we load a page
  class ContentfulSyncUpdate
    def initialize(app)
      @app = app
    end

    def call(env)
      if (Time.now - ContentfulSyncUpdate.last_sync) > 10.seconds
        ::WCC::Contentful::Services.instance.sync_engine&.next
        ContentfulSyncUpdate.last_sync = Time.now
      end

      @app.call(env)
    end

    class << self
      def last_sync
        @@last_sync ||= Time.at(0) # rubocop:disable Style/ClassVars
      end

      def last_sync=(time)
        @@last_sync = time # rubocop:disable Style/ClassVars
      end
    end
  end
end

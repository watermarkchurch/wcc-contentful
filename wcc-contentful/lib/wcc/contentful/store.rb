# frozen_string_literal: true

require_relative 'store/factory'

# The "Store" is the middle layer in the WCC::Contentful gem.  It exposes an API
# that implements the configured content delivery strategy.
#
# The different content delivery strategies require different store implementations.
#
# direct:: Uses the WCC::Contentful::Store::CDNAdapter to wrap the Contentful CDN,
#          providing an API consistent with the other stores.  Any query made to
#          the CDNAdapter will be immediately passed through to the API.
#          The CDNAdapter does not implement #index because it does not care about
#          updates coming from the Sync API.
#
# lazy_sync:: Uses the Contentful CDN in combination with an ActiveSupport::Cache
#             implementation in order to respond with the cached data where possible,
#             saving your CDN quota.  The cache is kept up-to-date via the Sync Engine
#             and the WCC::Contentful::SyncEngine::Job.  It is correct, but not complete.
#
# eager_sync:: Uses one of the full store implementations to store the entirety
#              of the Contentful space locally.  All queries are run against this
#              local copy, which is kept up to date via the Sync Engine and the
#              WCC::Contentful::SyncEngine::Job.  The local store is correct and complete.
#
# The currently configured store is available on WCC::Contentful::Services.instance.store
module WCC::Contentful::Store
  SYNC_STORES = {
    memory: ->(_config, *_options) { WCC::Contentful::Store::MemoryStore.new },
    postgres: ->(config, *options) {
      require_relative 'store/postgres_store'
      WCC::Contentful::Store::PostgresStore.new(config, *options)
    }
  }.freeze

  PRESETS = %i[
    eager_sync
    lazy_sync
    direct
    custom
  ].freeze
end

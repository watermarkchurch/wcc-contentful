# frozen_string_literal: true

# The CDN SimpleClient accesses 'https://cdn.contentful.com' to get raw
# JSON responses.  It exposes methods to query entries, assets, and content_types.
# The responses are instances of WCC::Contentful::SimpleClient::Response
# which handles paging automatically.
#
# @api Client
class WCC::Contentful::SimpleClient::Cdn < WCC::Contentful::SimpleClient
  def initialize(space:, access_token:, **options)
    super(
      api_url: options[:api_url] || 'https://cdn.contentful.com/',
      space: space,
      access_token: access_token,
      **options
    )
  end

  def client_type
    'cdn'
  end

  # Gets an entry by ID
  def entry(key, query = {})
    resp =
      _instrument 'entries', id: key, type: 'Entry', query: query do
        get("entries/#{key}", query)
      end
    resp.assert_ok!
  end

  # Queries entries with optional query parameters
  def entries(query = {})
    resp =
      _instrument 'entries', type: 'Entry', query: query do
        get('entries', query)
      end
    resp.assert_ok!
  end

  # Gets an asset by ID
  def asset(key, query = {})
    resp =
      _instrument 'entries', type: 'Asset', id: key, query: query do
        get("assets/#{key}", query)
      end
    resp.assert_ok!
  end

  # Queries assets with optional query parameters
  def assets(query = {})
    resp =
      _instrument 'entries', type: 'Asset', query: query do
        get('assets', query)
      end
    resp.assert_ok!
  end

  # Queries content types with optional query parameters
  def content_types(query = {})
    resp =
      _instrument 'content_types', query: query do
        get('content_types', query)
      end
    resp.assert_ok!
  end

  # Accesses the Sync API to get a list of items that have changed since
  # the last sync.
  #
  # If `sync_token` is nil, an initial sync is performed.
  # Returns a WCC::Contentful::SimpleClient::SyncResponse
  # which handles paging automatically.
  def sync(sync_token: nil, **query)
    sync_token =
      if sync_token
        { sync_token: sync_token }
      else
        { initial: true }
      end
    query = query.merge(sync_token)
    resp =
      _instrument 'sync', sync_token: sync_token, query: query do
        get('sync', query)
      end
    resp = SyncResponse.new(resp)
    resp.assert_ok!
  end
end

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

  # https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/tags/tag-collection/get-all-tags/console
  def tags(query = {})
    resp =
      _instrument 'tags', query: query do
        get('tags', query)
      end
    resp.assert_ok!
  end

  # Retrieves a single tag by ID
  #
  # @param id [String] The ID of the tag to retrieve
  # @param query [Hash] Optional query parameters
  # @return [Response] Response containing the tag
  # @raise [ArgumentError] If id is nil or empty
  # @example
  #   client.tag('sports')
  def tag(id, query = {})
    raise ArgumentError, 'id cannot be nil or empty' if id.nil? || id.empty?

    resp =
      _instrument 'tags', id: id, query: query do
        get("tags/#{id}", query)
      end
    resp.assert_ok!
  end

  # Accesses the Sync API to get a list of items that have changed since
  # the last sync.  Accepts a block that receives each changed item, and returns
  # the next sync token.
  #
  # If `sync_token` is nil, an initial sync is performed.
  #
  # @return String the next sync token parsed from nextSyncUrl
  # @example
  #    my_sync_token = storage.get('sync_token')
  #    my_sync_token = client.sync(sync_token: my_sync_token) do |item|
  #      storage.put(item.dig('sys', 'id'), item) }
  #    end
  #    storage.put('sync_token', my_sync_token)
  def sync(sync_token: nil, **query, &block)
    return sync_old(sync_token: sync_token, **query) unless block_given?

    query = {
      # override default locale for sync queries
      locale: nil
    }.merge(
      if sync_token
        { sync_token: sync_token }
      else
        { initial: true }
      end
    ).merge(query)

    _instrument 'sync', sync_token: sync_token, query: query do
      resp = get('sync', query)
      resp = SyncResponse.new(resp)
      resp.assert_ok!

      resp.each_page do |page|
        page.page_items.each(&block)
        sync_token = resp.next_sync_token
      end
    end

    sync_token
  end

  private

  def sync_old(sync_token: nil, **query)
    WCC::Contentful.deprecator.warn('Sync without a block is deprecated, please use new block syntax instead')

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
    resp = SyncResponse.new(resp, memoize: true)
    resp.assert_ok!
  end
end

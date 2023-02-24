# frozen_string_literal: true

module FixturesHelper
  def path_to_fixture(file_name)
    File.join(fixture_root, file_name)
  end

  def load_fixture(file_name)
    file = path_to_fixture(file_name)
    return unless File.exist?(file)

    File.read(file)
      .gsub(/343qxys30lid/i, contentful_space_id)
      .gsub('<CONTENTFUL_SPACE_ID>', contentful_space_id)
  end

  def fixture_root
    "#{File.dirname(__FILE__)}/../fixtures"
  end

  def load_indexed_types(file_name = 'contentful/indexed_types_from_content_type_indexer.json')
    serialized = JSON.parse(load_fixture(file_name))
    WCC::Contentful::IndexedRepresentation.from_json(serialized)
  end

  def load_store_from_sync(file_name: 'contentful/sync_initial.json', store: nil)
    sync_initial = JSON.parse(load_fixture(file_name).gsub(/343qxys30lid/, contentful_space_id))

    # We can no longer directly pass a store to the model layer, because the model layer
    # does not accept locale=* entries.  The store must have the locale support middleware.
    config = WCC::Contentful::Configuration.new
    config.store =
      if store.nil?
        %i[eager_sync memory]
      else
        [:custom, store]
      end
    services = WCC::Contentful::Services.new(config)

    services.store.tap do |s|
      sync_initial.each do |_k, v|
        s.index(v)
      end
    end
  end
end

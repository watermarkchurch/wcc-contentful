# frozen_string_literal: true

module FixturesHelper
  def load_fixture(file_name)
    file = File.join(fixture_root, file_name)
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

    store ||= WCC::Contentful::Store::MemoryStore.new
    sync_initial.each do |_k, v|
      store.index(v)
    end
    store
  end
end

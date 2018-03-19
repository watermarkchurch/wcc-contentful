
# frozen_string_literal: true

module FixturesHelper
  def load_fixture(file_name)
    file = "#{File.dirname(__FILE__)}/fixtures/#{file_name}"
    return File.read(file).gsub(/343qxys30lid/i, contentful_space_id) if File.exist?(file)
  end

  def load_indexed_types(file_name = 'contentful/indexed_types_from_content_type_indexer.json')
    serialized = JSON.parse(load_fixture(file_name))
    WCC::Contentful::IndexedRepresentation.from_json(serialized)
  end

  def load_store_from_sync(file_name: 'contentful/sync_initial.json', store: nil)
    sync_initial = JSON.parse(load_fixture(file_name).gsub(/343qxys30lid/, contentful_space_id))

    store ||= WCC::Contentful::Store::MemoryStore.new
    sync_initial.each do |k, v|
      store.index(k, v)
    end
    store
  end
end


# frozen_string_literal: true

module FixturesHelper
  def load_fixture(file_name)
    file = "#{File.dirname(__FILE__)}/fixtures/#{file_name}"
    return File.read(file) if File.exist?(file)
  end

  def load_indexed_types(file_name = 'contentful/indexed_types.json')
    JSON.parse(load_fixture(file_name))
      .each_with_object({}) do |(k, v), h|
        v = v.symbolize_keys
        v[:fields] =
          v[:fields].each_with_object({}) do |(k2, v2), h2|
            v2 = v2.symbolize_keys
            v2[:type] = v2[:type].to_sym
            h2[k2] = v2
          end
        h[k] = v
      end
  end

  def load_store_from_sync(file_name: 'contentful/sync_initial.json', store: nil)
    sync_initial = JSON.parse(load_fixture(file_name))

    store ||= WCC::Contentful::Sync::MemoryStore.new
    sync_initial.each do |k, v|
      store.index(k, v)
    end
    store
  end
end

# frozen_string_literal: true

RSpec.describe WCC::Contentful::ModelBuilder do
  let(:types) {
    JSON.parse(load_fixture('contentful/indexed_types.json'))
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
  }
  let(:store) {
    sync_initial = JSON.parse(load_fixture('contentful/sync_initial.json'))

    store = WCC::Contentful::Graphql::MemoryStore.instance
    sync_initial.each do |k, v|
      store.index(k, v)
    end
    store
  }
  subject {
    WCC::Contentful::ModelBuilder.new(types, store)
  }

  it 'builds models from loaded types' do
    # act
    schema = subject.build_models

    # assert
    expect(schema.map(&:to_s).sort).to eq(
      %w[
        WCC::Contentful::Asset
        WCC::Contentful::Faq
        WCC::Contentful::Homepage
        WCC::Contentful::Menu
        WCC::Contentful::MenuItem
        WCC::Contentful::MigrationHistory
        WCC::Contentful::Page
        WCC::Contentful::Redirect
        WCC::Contentful::Section_Faq
        WCC::Contentful::Section_VideoHighlight
      ]
    )

    expect(WCC::Contentful::Model.all_models).to include(WCC::Contentful::Page)
  end

  it 'finds types by ID' do
    schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    main_menu = WCC::Contentful::Model.find('FNlqULSV0sOy4IoGmyWOW')

    # assert
    expect(main_menu).to be_instance_of(WCC::Contentful::Menu)
    expect(main_menu.id).to eq('FNlqULSV0sOy4IoGmyWOW')
    expect(main_menu.created_at).to eq(Time.parse('2018-02-12T20:09:38.819Z'))
    expect(main_menu.updated_at).to eq(Time.parse('2018-02-12T21:59:43.653Z'))
    expect(main_menu.revision).to eq(2)
    expect(main_menu.space).to eq('343qxys30lid')

    expect(main_menu.name).to eq('Main Menu')
  end

  it 'resolves date times and json blobs'
end

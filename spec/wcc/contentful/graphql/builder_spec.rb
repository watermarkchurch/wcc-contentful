# frozen_string_literal: true

RSpec.describe WCC::Contentful::Graphql::Builder do
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
    WCC::Contentful::Graphql::Builder.new(types, store)
  }

  it 'builds a schema from loaded types' do
    # act
    schema = subject.build_schema

    # assert
    expect(schema).to_not be_nil
    types = schema.as_json.dig('data', '__schema', 'types')
    query = types.find { |t| t['name'] == 'Query' }
    expect(query['fields'].map { |f| f['name'] }.sort).to eq(
      %w[
        ContentfulAsset
        ContentfulFaq
        ContentfulHomepage
        ContentfulMenu
        ContentfulMenuItem
        ContentfulMigrationHistory
        ContentfulPage
        ContentfulRedirect
        ContentfulSection_Faq
        ContentfulSection_VideoHighlight
        allContentfulAsset
        allContentfulFaq
        allContentfulHomepage
        allContentfulMenu
        allContentfulMenuItem
        allContentfulMigrationHistory
        allContentfulPage
        allContentfulRedirect
        allContentfulSection_Faq
        allContentfulSection_VideoHighlight
      ]
    )
  end

  it 'finds types by ID' do
    schema = subject.build_schema

    # act
    query_string = '{
    homepage: ContentfulHomepage {
      id
      siteTitle
    }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    expect(result.to_h['data']).to eq(
      {
        'homepage' => {
          'id' => '4ssPJYNGPYQMMwo2gKmISo',
          'siteTitle' => 'Watermark Resources'
        }
      }
    )
  end

  it 'can filter by arbitrary field' do
    schema = subject.build_schema

    # act
    query_string = '{
      item: allContentfulMenuItem(filter: { field: "buttonStyle", eq: "rounded" }) {
        id
        text
      }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    expect(result.to_h['data']).to eq(
      { 'item' => [
        {
          'id' => '3Jmk4yOwhOY0yKsI6mAQ2a',
          'text' => 'Find A Ministry for Your Church'
        },
        {
          'id' => '3bZRv5ISCkui6kguIwM2U0',
          'text' => 'Ministries'
        },
        {
          'id' => '4Gye0ybf2EiWCgSyEg0cyE',
          'text' => 'Cart'
        }
      ] }
    )
  end
end

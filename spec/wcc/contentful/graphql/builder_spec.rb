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

  it 'resolves date times and json blobs' do
    schema = subject.build_schema

    # act
    query_string = '{
    migration: ContentfulMigrationHistory {
      id
      migrationName
      started
      completed
      detail
    }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    expect(result.to_h['data']['migration']).to include(
      {
        'id' => '7d73xC0RPiciy68yUWEoYU',
          'started' => Time.zone.parse('2018-02-22T21:12:45.621Z'),
          'completed' => Time.zone.parse('2018-02-22T21:12:46.699Z')
      }
    )

    expect(result.to_h.dig('data', 'migration', 'detail', 0, 'intent', 'intents')).to include(
      {
        'meta' => {
          'callsite' => {
            'file' => '/Users/gburgett/projects/wm/jtj-com/db/migrate/20180219160530_test_migration.ts',
            'line' => 3
          },
          'contentTypeInstanceId' => 'contentType/dog/0'
        },
        'type' => 'contentType/create',
        'payload' => {
          'contentTypeId' => 'dog'
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

  it 'resolves location' do
    schema = subject.build_schema

    # act
    query_string = '{
    faq: ContentfulFaq(id: "1nzrZZShhWQsMcey28uOUQ") {
      id
      placeOfFaq {
        lat
        lon
      }
    }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    loc = result.to_h['data']['faq']['placeOfFaq']
    expect(loc['lat']).to eq(52.5391688192368)
    expect(loc['lon']).to eq(13.4033203125)
  end

  it 'resolves linked types' do
    schema = subject.build_schema

    # act
    query_string = '{
    menu: ContentfulMenu(id: "FNlqULSV0sOy4IoGmyWOW") {
      hamburger {
        firstGroup {
          link {
            title
          }
        }
      }
    }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    expect(result.dig('data', 'menu', 'hamburger', 'firstGroup', 1, 'link', 'title'))
      .to eq('Mission')
  end

  it 'resolves linked assets' do
    schema = subject.build_schema

    # act
    query_string = '{
    homepage: ContentfulHomepage {
      heroImage {
        title
        file
      }
      favicons {
        file
      }
    }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    expect(result.dig('data', 'homepage', 'heroImage', 'title')).to eq('worship')
    expect(result.dig('data', 'homepage', 'heroImage', 'file', 'url')).to eq(
      '//images.contentful.com/343qxys30lid/' \
      '572YrsdGZGo0sw2Www2Si8/545f53511e362a78a8f34e1837868256/worship.jpg'
    )
    expect(result.dig('data', 'homepage', 'heroImage', 'file', 'contentType')).to eq('image/jpeg')

    expect(result.dig('data', 'homepage', 'favicons').length).to eq(4)
    expect(result.dig('data', 'homepage', 'favicons', 0, 'file', 'fileName')).to eq('favicon.ico')
  end
end

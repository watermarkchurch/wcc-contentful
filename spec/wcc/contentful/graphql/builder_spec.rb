# frozen_string_literal: true

RSpec.describe WCC::Contentful::Graphql::Builder do
  let(:types) { load_indexed_types }
  let(:store) { load_store_from_sync }
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
        Asset
        Faq
        Homepage
        Menu
        MenuItem
        MigrationHistory
        Page
        Redirect2
        Section_Faq
        Section_VideoHighlight
        allAsset
        allFaq
        allHomepage
        allMenu
        allMenuItem
        allMigrationHistory
        allPage
        allRedirect2
        allSection_Faq
        allSection_VideoHighlight
      ]
    )
  end

  it 'finds types by ID' do
    schema = subject.build_schema

    # act
    query_string = '{
    homepage: Homepage {
      id
      _content_type
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
          'siteTitle' => 'Watermark Resources',
          '_content_type' => 'homepage'
        }
      }
    )
  end

  it 'resolves date times and json blobs' do
    schema = subject.build_schema

    # act
    query_string = '{
    migration: MigrationHistory {
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
      item: allMenuItem(filter: { field: "buttonStyle", eq: "rounded" }) {
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
    faq: Faq(id: "1nzrZZShhWQsMcey28uOUQ") {
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
    faq: Section_Faq(id: "6nDGEkPhn28Awg2MqeEAAK") {
      faqs {
        question
        answer
      }
    }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    expect(result.dig('data', 'faq', 'faqs', 0, 'question'))
      .to eq('A Faq')
  end

  it 'resolves discriminated linked types' do
    schema = subject.build_schema

    # act
    query_string = '{
    home: Homepage {
      sections {
        ... on Section_Faq {
          faqs {
            question
            answer
          }
        }
        ... on Section_VideoHighlight {
          youtubeLink
        }
      }
    }
    }'
    result = schema.execute(query_string)

    # assert
    expect(result.to_h['errors']).to be_nil
    expect(result.dig('data', 'home', 'sections').length).to eq(2)
    expect(result.dig('data', 'home', 'sections', 0, 'faqs').length).to eq(2)
    expect(result.dig('data', 'home', 'sections', 1, 'youtubeLink'))
      .to eq('https://youtu.be/pyrxj8gRRLo')
  end

  it 'resolves linked assets' do
    schema = subject.build_schema

    # act
    query_string = '{
    homepage: Homepage {
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

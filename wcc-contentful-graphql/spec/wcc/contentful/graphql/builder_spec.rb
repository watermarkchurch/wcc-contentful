# frozen_string_literal: true

require 'wcc/contentful/graphql'

RSpec.describe WCC::Contentful::Graphql::Builder do
  subject {
    WCC::Contentful::Graphql::Builder.new(types, store).configure do
      root_module WCC::Contentful::Graphql::Types::Test
    end
  }

  module WCC::Contentful::Graphql::Types::Test
  end

  let(:namespace) {
    WCC::Contentful::Graphql::Types::Test
  }

  before do
    # clean out everything in the generated namespace
    consts = WCC::Contentful::Graphql::Types::Test.constants(false).map(&:to_s).uniq
    consts.each do |c|
      begin
        WCC::Contentful::Graphql::Types::Test.send(:remove_const, c.split(':').last)
      rescue StandardError => e
        warn e
      end
    end
  end

  context 'from sync indexer' do
    let(:types) { load_indexed_types }
    let(:store) { load_store_from_sync }

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
          Dog
          Faq
          Homepage
          Menu
          MenuButton
          MigrationHistory
          Ministry
          MinistryCard
          Page
          Redirect2
          SectionCardsearch
          SectionFaq
          SectionTestimonials
          SectionVideohighlight
          Testimonial
          Theme
          allAsset
          allDog
          allFaq
          allHomepage
          allMenu
          allMenuButton
          allMigrationHistory
          allMinistry
          allMinistryCard
          allPage
          allRedirect2
          allSectionCardsearch
          allSectionFaq
          allSectionTestimonials
          allSectionVideohighlight
          allTestimonial
          allTheme
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
              'file' =>
                '/Users/gburgett/projects/wm/jtj-com/db/migrate/20180219160530_test_migration.ts',
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
      query_string = '
      query menuButtonByStyle($style: String!) {
        buttons: allMenuButton(filter: { buttonStyle: { eq: $style } }) {
          id
          text
        }
      }'
      result = schema.execute(query_string, variables: { 'style' => 'rounded' })

      # assert
      expect(result.to_h['errors']).to be_nil
      expect(result.to_h['data']['buttons'].count).to eq(3)
      expect(result.to_h['data']).to eq(
        { 'buttons' => [
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

    it 'can query by arbitrary field' do
      schema = subject.build_schema

      # act
      query_string = '
      query menuButtonByStyle($text: String!) {
        MenuButton(text: { eq: $text }) {
          id
          text
        }
      }'
      result = schema.execute(query_string, variables: { 'text' => 'Ministries' })

      # assert
      expect(result.to_h['errors']).to be_nil
      expect(result.to_h['data']).to eq(
        {
          'MenuButton' => {
            'id' => '3bZRv5ISCkui6kguIwM2U0',
            'text' => 'Ministries'
          }
        }
      )
    end

    it 'resolves coordinates' do
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
      faq: SectionFaq(id: "6nDGEkPhn28Awg2MqeEAAK") {
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
          ... on SectionFaq {
            _content_type
            faqs {
              question
              answer
            }
          }
          ... on SectionVideohighlight {
            _content_type
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
      expect(result.dig('data', 'home', 'sections', 0, '_content_type')).to eq('section-Faq')
      expect(result.dig('data', 'home', 'sections', 1, 'youtubeLink'))
        .to eq('https://youtu.be/pyrxj8gRRLo')
      expect(result.dig('data', 'home', 'sections', 1, '_content_type')).to eq('section-VideoHighlight')
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
        "//images.contentful.com/#{contentful_space_id}/" \
        '572YrsdGZGo0sw2Www2Si8/545f53511e362a78a8f34e1837868256/worship.jpg'
      )
      expect(result.dig('data', 'homepage', 'heroImage', 'file', 'contentType')).to eq('image/jpeg')

      expect(result.dig('data', 'homepage', 'favicons').length).to eq(4)
      expect(result.dig('data', 'homepage', 'favicons', 0, 'file', 'fileName')).to eq('favicon.ico')
    end
  end

  context 'from content type indexer' do
    let(:types) { load_indexed_types('contentful/indexed_types_from_content_type_indexer.json') }
    let(:store) { load_store_from_sync }

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
          Dog
          Faq
          Homepage
          Menu
          MenuButton
          MigrationHistory
          Ministry
          MinistryCard
          Page
          Redirect2
          SectionCardsearch
          SectionFaq
          SectionTestimonials
          SectionVideohighlight
          Testimonial
          Theme
          allAsset
          allDog
          allFaq
          allHomepage
          allMenu
          allMenuButton
          allMigrationHistory
          allMinistry
          allMinistryCard
          allPage
          allRedirect2
          allSectionCardsearch
          allSectionFaq
          allSectionTestimonials
          allSectionVideohighlight
          allTestimonial
          allTheme
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
              'file' =>
                '/Users/gburgett/projects/wm/jtj-com/db/migrate/20180219160530_test_migration.ts',
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
      faq: SectionFaq(id: "6nDGEkPhn28Awg2MqeEAAK") {
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
          ... on SectionFaq {
            faqs {
              question
              answer
            }
          }
          ... on SectionVideohighlight {
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
        "//images.contentful.com/#{contentful_space_id}/" \
        '572YrsdGZGo0sw2Www2Si8/545f53511e362a78a8f34e1837868256/worship.jpg'
      )
      expect(result.dig('data', 'homepage', 'heroImage', 'file', 'contentType')).to eq('image/jpeg')

      expect(result.dig('data', 'homepage', 'favicons').length).to eq(4)
      expect(result.dig('data', 'homepage', 'favicons', 0, 'file', 'fileName')).to eq('favicon.ico')
    end

    it 'can remove types from root' do
      schema = subject.tap do |builder|
        builder.root_types.delete('menuButton')
      end.build_schema

      # act
      query1 = '{
        button: MenuButton(text: { eq: "Ministries" }) {
          id
          text
        }
      }'
      query2 = '{
        menu: Menu(id: "FNlqULSV0sOy4IoGmyWOW") {
          secondGroup {
            ... on MenuButton {
              id
              text
            }
          }
        }
      }'
      result1 = schema.execute(query1)
      result2 = schema.execute(query2)

      expect(result1['errors']).to_not be nil
      expect(result2['errors']).to be nil
      expect(result2.dig('data', 'menu', 'secondGroup', 0, 'text')).to eq('Ministries')
    end

    it 'can modify fields' do
      markdown_redcarpet_type =
        GraphQL::ObjectType.define do
          name 'markdownRedcarpet'

          field :text, !types.String do
            resolve ->(object, _args, _ctx) {
              object
            }
          end
          field :html, !types.String do
            resolve ->(_object, _args, _ctx) {
              '<div>Some HTML</div>'
            }
          end
        end

      schema = subject.build_schema
      WCC::Contentful::Graphql::Types::Test::Faq.class_exec do
        contentful_field :answer, markdown_redcarpet_type
      end

      query_string = '{
      faq: Faq(id: "1nzrZZShhWQsMcey28uOUQ") {
        question
        answer {
          text
          html
        }
      }
      }'
      result = schema.execute(query_string)

      expect(result['errors']).to be nil
      expect(result['data'].dig('faq', 'question')).to eq('A Faq')
      expect(result['data'].dig('faq', 'answer', 'text')).to eq('This is my anwers')
      expect(result['data'].dig('faq', 'answer', 'html')).to eq('<div>Some HTML</div>')
    end
  end

  context 'when types is a string' do
    let(:types) { File.join(fixture_root, 'contentful/contentful-schema.json') }
    let(:store) { double('store') }

    it 'attempts to load from file' do
      schema = subject.build_schema

      expect(schema.types['Menu']&.name).to eq('Menu')
      expect(schema.types['Testimonial']&.name).to eq('Testimonial')
    end
  end
end

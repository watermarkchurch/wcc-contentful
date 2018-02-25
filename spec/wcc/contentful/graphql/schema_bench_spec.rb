# frozen_string_literal: true

RSpec.shared_examples 'graphql querying' do
  it 'bench find by id' do
    query_string = '
    query getMenuItem($id: ID!) {
      ContentfulMenuItem(id: $id) {
        id
        text
        iconFA
        buttonStyle
        customButtonCss
        externalLink
      }
    }
    '

    schema = nil
    run_bench(content_type: 'menuItem',
              store_builder: store_builder,
              before: ->(store) {
                        schema = WCC::Contentful::Graphql::Builder.new(
                          types,
                          store
                        ).build_schema
                      }) do |id|

      result = schema.execute(query_string, variables: { 'id' => id })
      expect(result.to_h['errors']).to be_nil
      expect(result.to_h.dig('data', 'ContentfulMenuItem', 'id')).to eq(id)
    end
  end

  it 'bench Homepage expand 15 links' do
    query_string = '{
      homepage: ContentfulHomepage {
        id
        mainMenu {
          icon {
            file
          }
          secondGroup {
            link {
              title
            }
          }
          thirdGroup {
            link {
              title
            }
          }
          hamburger {
            firstGroup {
              link {
                title
              }
            }
          }
        }
        heroButtons {
          id
        }
      }
    }'

    schema = nil
    run_bench(store_builder: store_builder,
              before: ->(store) {
                        schema = WCC::Contentful::Graphql::Builder.new(
                          types,
                          store
                        ).build_schema
                      }) do |_id|

      result = schema.execute(query_string)
      expect(result.to_h['errors']).to be_nil
    end
  end

  it 'bench find with filter (find_by equivalend)' do
    query_string = 'query menuItemQuery($style: Any) {
      items: allContentfulMenuItem(filter: { field: "buttonStyle", eq: $style }) {
        id
        text
        iconFA
        buttonStyle
        customButtonCss
        externalLink
      }
    }'
    styles = ['custom', 'rounded', 'external', 'value doesnt exist']

    schema = nil
    run_bench(store_builder: store_builder,
              before: ->(store) {
                        schema = WCC::Contentful::Graphql::Builder.new(
                          types,
                          store
                        ).build_schema
                      }) do |_, i|

      result = schema.execute(
        query_string,
        variables: { 'style' => styles[i % styles.length] }
      )
      expect(result.to_h['errors']).to be_nil
    end
  end

  it 'bench find single with filter' do
    query_string = 'query redirectQuery($slug: Any) {
      redirect: allContentfulRedirect2(filter: { field: "slug", eq: $slug }) {
        id
        slug
        pageReference {
          id
          title
        }
      }
    }'

    schema = nil
    run_bench(store_builder: store_builder,
              before: ->(store) {
                        schema = WCC::Contentful::Graphql::Builder.new(
                          types,
                          store
                        ).build_schema
                      }) do

      result = schema.execute(
        query_string,
        variables: { 'slug' => 'mister_roboto' }
      )
      expect(result.to_h['errors']).to be_nil
      expect(result.dig('data', 'redirect').length).to eq(1)
      expect(result.dig('data', 'redirect', 0, 'pageReference', 'title')).to eq('Conferences')
    end
  end
end

RSpec.describe 'graphql querying', :bench do
  include BenchHelper

  let(:types) { load_indexed_types }

  context 'with MemoryStore' do
    let(:store_builder) {
      -> { WCC::Contentful::Sync::MemoryStore.new }
    }
    include_examples 'graphql querying'
  end

  context 'with postgres store' do
    let!(:store_builder) {
      -> {
        begin
          conn = PG.connect(ENV['POSTGRES_CONNECTION'] || { dbname: 'contentful' })

          conn.exec('DROP TABLE IF EXISTS contentful_raw')
        ensure
          conn.close
        end
        WCC::Contentful::Model.store = WCC::Contentful::Sync::PostgresStore.new(ENV['POSTGRES_CONNECTION'])
      }
    }

    include_examples 'graphql querying'
  end
end

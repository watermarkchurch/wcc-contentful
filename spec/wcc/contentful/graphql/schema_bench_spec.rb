# frozen_string_literal: true

RSpec.describe 'graphql querying', :bench do
  include BenchHelper

  let(:types) { load_indexed_types }
  let(:build_schema) {
    ->(store) {
      WCC::Contentful::Graphql::Builder.new(
        types,
        store
      ).build_schema
    }
  }

  context 'with MemoryStore' do
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
      run_bench(content_type: 'menuItem',
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
      run_bench(content_type: 'menuItem',
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
  end
end

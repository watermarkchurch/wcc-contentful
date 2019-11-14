# frozen_string_literal: true

require 'diffy'
require 'wcc/contentful/graphql'

RSpec.describe WCC::Contentful::Graphql::Federation do
  let(:schema1) {
    query_type = root_query_type_1
    GraphQL::Schema.define do
      query query_type

      resolve_type ->(_obj, _ctx) { raise StandardError, 'should not be invoked!' }
    end
  }

  let(:root_query_type_1) {
    GraphQL::ObjectType.define do
      name 'Query'

      field 'field1' do
        type types.String

        resolve(proc { 'field1 test string' })
      end
    end
  }

  let(:root_query_type_2) {
    type_b = schema_2_type_b
    field_arg_type = field_b_argument_type
    GraphQL::ObjectType.define do
      name 'Query2'

      field 'a' do
        type types.String

        resolve(proc { "field 'a' test string" })
      end
      # remote delegated type
      field 'b', type_b do
        argument 'some_arg', field_arg_type
      end
    end
  }

  let(:field_b_argument_type) {
    GraphQL::InputObjectType.define do
      name 'FilterInput'

      argument 'eq', types.String
    end
  }

  let(:schema_2_type_b) {
    GraphQL::ObjectType.define do
      name 'B_type'

      field 'c' do
        type types.String
        resolve(proc { |obj| obj['c'] })
      end
    end
  }

  describe '.delegate_to_schema' do
    it 'can delegate to a second schema' do
      schema2 = double('schema2')
      delegated_b_type = schema_2_type_b
      root_query_type_1.define do
        field 'b', delegated_b_type do
          resolve delegate_to_schema(schema2)
        end
      end

      expected_query = <<~QUERY
        query {
          b {
            c
          }
        }
      QUERY

      expect(schema2).to receive(:execute) do |params|
        expect(params[:document]).to match_query(expected_query.strip)
        { 'data' => { 'b' => { 'c' => 'test c' } } }
      end

      result = schema1.execute(<<~QUERY)
        {
          field1
          b {
            c
          }
        }
      QUERY

      expect(result['errors']).to eq nil
      expect(result['data']).to eq({
        'field1' => 'field1 test string',
        'b' => {
          'c' => 'test c'
        }
      })
    end

    it 'can pass arguments' do
      schema2 = double('schema2')
      delegated_b_type = schema_2_type_b
      root_query_type_1.define do
        field 'filtered_b_value', delegated_b_type do
          resolve delegate_to_schema(schema2,
            field_name: 'b',
            arguments: proc { { some_arg: { eq: 'test' } } })
        end
      end

      expected_query = <<~QUERY
        query {
          b(some_arg: {eq: "test"}) {
            c
          }
        }
      QUERY

      expect(schema2).to receive(:execute) do |params|
        expect(params[:document]).to match_query(expected_query.strip)
        { 'data' => { 'b' => { 'c' => 'test c' } } }
      end

      result = schema1.execute(<<~QUERY)
        {
          field1
          filtered_b_value {
            c
          }
        }
      QUERY

      expect(result['errors']).to eq nil
      expect(result['data']).to eq({
        'field1' => 'field1 test string',
        'filtered_b_value' => {
          'c' => 'test c'
        }
      })
    end

    it 'propagates query params' do
      schema2 = double('schema2')
      delegated_b_type = schema_2_type_b
      root_query_type_1.define do
        field 'b', delegated_b_type do
          resolve delegate_to_schema(schema2)
        end
      end

      d_type =
        GraphQL::ObjectType.define do
          name 'D_type'
          field 'e', types.String do
            resolve(proc { |obj| obj['e'] })
          end
        end
      schema_2_type_b.define do
        field 'd' do
          argument :some_arg, types.String
          type d_type
          resolve(proc { |obj| obj['d'] })
        end
      end

      expected_query = <<~QUERY
        query myQuery($myvar: String!) {
          b {
            d(some_arg: $myvar) {
              e
            }
          }
        }
      QUERY

      expect(schema2).to receive(:execute) do |params|
        expect(params[:document]).to match_query(expected_query.strip)
        { 'data' => { 'b' => { 'd' => { 'e' => 'test e value' } } } }
      end

      result = schema1.execute(<<~QUERY, variables: { 'myvar' => 'testvar' })
        query myQuery($myvar: String!) {
          b {
            d(some_arg: $myvar) {
              e
            }
          }
        }
      QUERY

      expect(result['errors']).to eq nil
      expect(result['data']).to eq({
        'b' => {
          'd' => {
            'e' => 'test e value'
          }
        }
      })
    end

    it 'can delegate to a Contentful schema type' do
      indexed_types = load_indexed_types
      store = load_store_from_sync
      contentful_schema = WCC::Contentful::Graphql::Builder.new(indexed_types, store).build_schema

      root_query_type_1.define do
        field(:MenuButton, -> { contentful_schema.types['MenuButton'] }) do
          argument :id, types.String

          resolve delegate_to_schema(contentful_schema,
            field_name: 'MenuButton')
        end
      end

      result = schema1.execute(<<~QUERY)
        {
          MenuButton(id: "ZosJIuGfgkky0cA2GsymW") {
            id
            text
            link {
              id
              title
              slug
            }
          }
        }
      QUERY

      expect(result['errors']).to eq nil
      expect(result['data']).to eq({
        'MenuButton' => {
          'id' => 'ZosJIuGfgkky0cA2GsymW',
          'text' => 'Terms & Conditions',
          'link' => {
            'id' => '1loILDsvKYkmGWoiKOOgkE',
            'title' => 'Terms & Conditions',
            'slug' => 'terms-and-conditions'
          }
        }
      })
    end
  end

  describe '.schema_stitch' do
    it 'adds the schema in at root' do
      query_type2 = root_query_type_2
      schema2 =
        GraphQL::Schema.define do
          query query_type2
        end

      # in the first schema's root query
      root_query_type_1.define do
        schema_stitch(schema2)
      end

      expected_query = <<~QUERY
        query {
          b {
            c
          }
        }
      QUERY

      expect(schema2).to receive(:execute) do |params|
        expect(params[:document]).to match_query(expected_query.strip)
        { 'data' => { 'b' => { 'c' => 'test c' } } }
      end

      # act
      result = schema1.execute(<<~QUERY)
        {
          field1
          b {
            c
          }
        }
      QUERY

      expect(result['errors']).to eq nil
      expect(result['data']).to eq({
        'field1' => 'field1 test string',
        'b' => {
          'c' => 'test c'
        }
      })
    end

    it 'adds the schema in under a namespace' do
      query_type2 = root_query_type_2
      schema2 =
        GraphQL::Schema.define do
          query query_type2
        end

      # in the first schema's root query
      root_query_type_1.define do
        schema_stitch(schema2, namespace: 'Other', field: 'other')
      end

      expected_query = <<~QUERY
        query {
          b {
            c
          }
        }
      QUERY

      expect(schema2).to receive(:execute) do |params|
        expect(params[:document]).to match_query(expected_query.strip)
        { 'data' => { 'b' => { 'c' => 'test c' } } }
      end

      # act
      result = schema1.execute(<<~QUERY)
        {
          field1
          other {
            b {
              c
            }
          }
        }
      QUERY

      expect(result['errors']).to eq nil
      expect(result['data']).to eq({
        'field1' => 'field1 test string',
        'other' => {
          'b' => {
            'c' => 'test c'
          }
        }
      })
    end

    it 'puts the other schemas types under a namespace' do
      query_type2 = root_query_type_2
      schema2 =
        GraphQL::Schema.define do
          query query_type2
        end

      # in the first schema's root query
      root_query_type_1.define do
        schema_stitch(schema2, namespace: 'Other')
      end

      expect(schema1.types['B_type']).to be nil
      expect(schema1.types['Other_B_type']).to_not be nil
    end

    it 'allows explicit variable naming of input types' do
      query_type2 = root_query_type_2
      schema2 =
        GraphQL::Schema.define do
          query query_type2
        end

      # in the first schema's root query
      root_query_type_1.define do
        schema_stitch(schema2, namespace: 'Other', field: 'other')
      end

      expected_query = <<~QUERY
        query withFilter($filter: FilterInput) {
          b(some_arg: $filter) {
            c
          }
        }
      QUERY

      expect(schema2).to receive(:execute) do |params|
        expect(params[:document]).to match_query(expected_query.strip)
        { 'data' => { 'b' => { 'c' => 'test c' } } }
      end

      # act
      result = schema1.execute(<<~QUERY, variables: { filter: { eq: 'test' } })
        query withFilter($filter: Other_FilterInput) {
          other {
            b(some_arg: $filter) {
              c
            }
          }
        }
      QUERY

      expect(result['errors']).to eq nil
    end
  end
end

RSpec::Matchers.define :graphql_variables do |expected|
  match do |actual|
    actual.instance_variable_get('@provided_variables') == expected
  end
end

RSpec::Matchers.define :match_query do |expected|
  match do |actual|
    diff = Diffy::Diff.new(expected, actual.to_query_string)
    diff.count == 0
  end

  failure_message do |actual|
    Diffy::Diff.new(expected, actual.to_query_string).to_s(:color)
  end
end

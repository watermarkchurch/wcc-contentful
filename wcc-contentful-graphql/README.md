[![Gem Version](https://badge.fury.io/rb/wcc-contentful-graphql.svg)](https://rubygems.org/gems/wcc-contentful-graphql)
[![Build Status](https://travis-ci.org/watermarkchurch/wcc-contentful.svg?branch=master)](https://travis-ci.org/watermarkchurch/wcc-contentful)
[![Coverage Status](https://coveralls.io/repos/github/watermarkchurch/wcc-contentful/badge.svg?branch=master)](https://coveralls.io/github/watermarkchurch/wcc-contentful?branch=master)

# WCC::Contentful::Graphql

This gem creates a GraphQL schema over your configured [data store](https://www.rubydoc.info/gems/wcc-contentful#Store_API).
You can execute queries against this GraphQL schema to get all your contentful
data.  Under the hood, queries are executed against your backing store to
resolve all the requested data.

### Important note!
The GraphQL schema currently does not utilize the "include" parameter, so it is
a very good idea to configure your store to either `:eager_sync`
or `:lazy_sync`.  If you don't do this, you will see a lot of requests to
Contentful for specific entries by ID as the GraphQL resolver walks all your links!

[More info on configuration can be found here](https://www.rubydoc.info/gems/wcc-contentful/WCC%2FContentful%2FConfiguration:store=)

## Usage

Querying directly within your app
```rb
schema = WCC::Contentful::Services.instance.graphql_schema
=> #<GraphQL::Schema ...>

result = schema.execute(<<~QUERY)
          {
            allConference(filter: { code: { eq: "CLC2020" } }) {
              title
              startDate
              code
            }
          }
        QUERY
GET https://cdn.contentful.com/spaces/xxxxx/entries?content_type=conference&fields.code.en-US=CLC2020&locale=%2A
Status 200
=> #<GraphQL::Query::Result @query=... @to_h={"data"=>{"allConference"=>[{"title"=>"Church Leaders Conference", "startDate"=>"2020-04-28", "code"=>"CLC2020"}]}}>
result.to_h
=> {"data"=>
  {"allConference"=>
    [{"title"=>"Church Leaders Conference",
      "startDate"=>"2020-04-28",
      "code"=>"CLC2020"}]}}
```

Setting up a controller to respond to GraphQL queries

```rb
class Api::GraphqlController < Api::BaseController
  include WCC::Contentful::ServiceAccessors

  skip_before_action :authenticate_user!, only: :query

  def query
    result = graphql_schema.execute(
      params[:query],
      variables: params[:variables]
    )
    render json: result
  end
end
```

## Advanced Configuration

### Including your Contentful schema inside another GraphQL schema

```rb
QueryType = GraphQL::ObjectType.define do
  # extend this to get 'schema_stitch'
  extend WCC::Contentful::Graphql::Federation

  name 'RootQuery'

  field 'a', types.String

  schema_stitch(WCC::Contentful::Services.instance.graphql_schema,
    namespace: 'contentful')
end

Schema = GraphQL::Schema.define do
  query QueryType
  
  resolve_type ->(type, obj, ctx) {
    raise StandardError, "Cannot resolve type #{type} #{obj.inspect} #{ctx.inspect}"
  }
end

File.write('schema.gql', GraphQL::Schema::Printer.print_schema(Schema))
```
results in...
```gql
schema {
  query: RootQuery
}

type Contentful {
  """
  Find a Asset
  """
  Asset(_content_type: Contentful_StringQueryOperatorInput, description: Contentful_StringQueryOperatorInput, id: ID, title: Contentful_StringQueryOperatorInput): Contentful_Asset

  """
  Find a CallToAction
  """
  CallToAction(_content_type: Contentful_StringQueryOperatorInput, id: ID, internalTitle: Contentful_StringQueryOperatorInput, style: Contentful_StringQueryOperatorInput, text: Contentful_StringQueryOperatorInput, title: Contentful_StringQueryOperatorInput): Contentful_CallToAction
...
```

### Limiting the schema to only a few fields

```rb
store = WCC::Contentful::Services.instance.store
builder =
  WCC::Contentful::Graphql::Builder.new(
    WCC::Contentful.types,
    store,
  ).configure do
    root_types.slice!('conference')

    schema_types['conference'].define do
      # change the types of some fields, undefine fields, etc...
    end
  end

@schema = builder.build_schema
```

# Store API

The Store layer is used by the Model API to access Contentful data in a raw form.
The Store layer returns entries as hashes parsed from JSON, conforming to the
object structure returned from the Contentful CDN.

## Public Interface

See WCC::Contentful::Store::Interface in wcc/contentful/store/interface.rb

This is the interface consumed by higher layers, such as the Model and GraphQL
APIs.  It implements the following methods:

* `index?` - Returns boolean true if the SyncEngine should call the store's `index(json)`
  method with the results of a Sync.
* `index(json)` - Updates the store with the latest data.  The JSON can be an Entry,
  Asset, DeletedEntry, or DeletedAsset.
* `find(id)` - Finds an entry or asset by it's ID.
* `find_all(content_type:, options: nil)` - Returns a query object that can be
  enumerated to lazily iterate over all values of a content type.  Query conditions
  can be applied on the query object before it is enumerated to restrict the result
  set.
* `find_by(content_type:, filter: nil, options: nil)` - Returns the first entry 
  of the given content type which matches the filter.  
  Note: assets have the special content
    type of `Asset` (capital A)

## Implementing your own store

The most straightforward way to implement a store is to include the
WCC::Contentful::Store::Interface module and then override all the defined
methods.  The easiest way however, is to inherit from WCC::Contentful::Store::Base
and override the `set`, `delete`, `find`, and `execute` methods.

Let's take a look at the MemoryStore for a simplistic example.  The MemoryStore
stores entries in a simple Ruby hash keyed by entry ID.  `set` is simply
assigning to the key in the hash and returning the old value. `delete` and `find`
are likewise simple.  The only complex method is `execute`, because it powers the
`find_by` and `find_all` query methods.

The query passed in to `execute` is an instance of WCC::Contentful::Store::Query.
This object contains a set of WCC::Contentful::Store::Query::Condition structs.
Each struct is a tuple of `path`, `op`, and `expected`.  `op` is one of
WCC::Contentful::Store::Query::Interface::OPERATORS, `path` is an array of fields
pointing to a value in the JSON representation of an entry, and `expected` is the
expected value that should be compared to the value selected by `path`.

Since the MemoryStore only implements the equality operator, it simply digs
out the value at the given path using `val = entry.dig(*condition.path)`
and compares it using Contentful's definition of equality:
```rb
# For arrays, equality is defined as does the array include the expected value.
# See https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/search-parameters/array-equality-inequality
if val.is_a? Array
  val.include?(condition.expected)
else
  val == condition.expected
end
```

### RSpec shared examples

To ensure you have implemented all the appropriate behavior, there
are a set of rspec shared examples in wcc/contentful/store/rspec_examples.rb which
you can include in your specs for your store implementation.  Let's look at
spec/wcc/contentful/store/memory_store_spec.rb to see how it's used:

```rb
require 'wcc/contentful/store/rspec_examples'

RSpec.describe WCC::Contentful::Store::MemoryStore do
  subject { WCC::Contentful::Store::MemoryStore.new }

  it_behaves_like 'contentful store', {
    # memory store does not support JOINs like `Player.find_by(team: { slug: 'dallas-cowboys' })
    nested_queries: false,
    # Memory store supports resolving includes, but it does so in the most naiive
    # way possible (by recursing down the entry's links and calling #find on every one)
    include_param: 0
  }
```

The hash passed to the shared examples describes the features that the store
supports.  Any key not provided causes the specs to be given the 'pending'
attribute.  You can disable a set of specs by providing `false` for that key.

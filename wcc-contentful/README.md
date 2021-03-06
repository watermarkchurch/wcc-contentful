[![Gem Version](https://badge.fury.io/rb/wcc-contentful.svg)](https://rubygems.org/gems/wcc-contentful)
[![Build Status](https://circleci.com/gh/watermarkchurch/wcc-contentful.svg?style=svg)](https://circleci.com/gh/watermarkchurch/wcc-contentful)
[![Coverage Status](https://coveralls.io/repos/github/watermarkchurch/wcc-contentful/badge.svg?branch=master)](https://coveralls.io/github/watermarkchurch/wcc-contentful?branch=master)

Full documentation: https://watermarkchurch.github.io/wcc-contentful/latest/wcc-contentful/

# WCC::Contentful

An alternative to Contentful's [contentful.rb ruby client](https://github.com/contentful/contentful.rb/), [contentful_model](https://github.com/contentful/contentful_model), and [contentful_rails](https://github.com/contentful/contentful_rails) gems all in one.

Table of Contents:

1. [Why?](#why-did-you-rewrite-the-contentful-ruby-stack)
2. [Installation](#installation)
3. [Configuration](#configure)
4. [Usage](#usage)
  1. [Model API](#wcccontentfulmodel-api)
  2. [Store API](#store-api)
  3. [Direct CDN client](#direct-cdn-api-simpleclient)
  4. [Accessing the APIs](#accessing-the-apis-within-application-code)
5. [Architecture](#architecture)
6. [Test Helpers](#test-helpers)
7. [Advanced Configuration Example](#advanced-configuration-example)
8. [Development](#development)
9. [Contributing](#contributing)
10. [License](#license)


## Why did you rewrite the Contentful ruby stack?

We started working with Contentful almost 3 years ago.  Since that time, Contentful's ruby stack has improved, but there are still a number of pain points that we feel we have addressed better with our gem.  These are:

* [Low-level caching](#low-level-caching)
* [Better integration with Rails & Rails models](#better-rails-integration)
* [Automatic pagination and Automatic link resolution](#automatic-pagination-and-link-resolution)
* [Automatic webhook management](#automatic-webhook-management)

Our gem no longer depends on any of the Contentful gems and interacts directly with the [Contentful CDA](https://www.contentful.com/developers/docs/references/content-delivery-api/) and [Content Management API](https://www.contentful.com/developers/docs/references/content-management-api/) over HTTPS.

### Low-level caching

The wcc-contentful gem enables caching at two levels: the HTTP response using [Faraday HTTP cache middleware](https://github.com/sourcelevel/faraday-http-cache), and at the Entry level using the Rails cache and the [Sync API](https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/synchronization) to keep it up to date.  We've found these two cache layers to be very effective at reducing both round trip latency to the Content Delivery API, as well as reducing our monthly API request usage. (which reduces our overage charges.  Hooray!)

#### At the request/response level
By default, the contentful.rb gem requires the [HTTP library](https://rubygems.org/gems/http).  While simple and straightforward to use, it is not as powerful for caching.  We decided to make our client conform to the [Faraday gem's API](https://github.com/lostisland/faraday).  If you prefer not to use Faraday, you can choose to supply your own HTTP adapter that "quacks like" Faraday (see the [TyphoeusAdapter](https://github.com/watermarkchurch/wcc-contentful/blob/master/wcc-contentful/lib/wcc/contentful/simple_client/typhoeus_adapter.rb) for one implementation).

Using Faraday makes it easy to add Middleware.  As an example, our flagship Rails app that powers watermark.org uses the following configuration in Production, which provides us with instrumentation through statsd, logging, and caching:
```rb
config.connection = Faraday.new do |builder|
  builder.use :http_cache,
    shared_cache: false,
    store: ActiveSupport::Cache::MemoryStore.new(size: 512.megabytes),
    logger: Rails.logger,
    serializer: Marshal,
    instrumenter: ActiveSupport::Notifications

  builder.use :gzip
  builder.response :logger, Rails.logger, headers: false, bodies: false if Rails.env.development?
  builder.request :instrumentation
  builder.adapter :typhoeus
end
```

#### At the Entry level

Our stack has three layers, the middle layer being essentially a cache for individual Entry hashes parsed out of responses from the Delivery API.  We were able to add a caching layer here which stores entries retrieved over the Sync API, and responds to queries with cached versions of local content when possible.  We consider this to be our best innovation on the Contentful ruby stack.

We have successfully created caching layers using Memcached, Postgres, and an in-memory hash.  The architecture allows other caching implementations to be created fairly easily, and we have a set of rspec specs that can verify that a cache store behaves appropriately.  For more information, [see the documentation on the caching modes here](https://watermarkchurch.github.io/wcc-contentful/latest/wcc-contentful/WCC/Contentful/Store.html).

### Better Rails Integration

When we initially got started with the Contentful ruby models, we encountered one problem that was more frustrating than all others: If a field exists in the content model, but the particular entry we're working with does not have that field populated, then accessing that field raised a `NoMethodError`.  This caused us to litter our code with `if defined?(entry.my_field)` which is bad practice.  (Note: this has since been fixed in contentful.rb v2).

We decided it was better to not rely on `method_missing?` (what contentful.rb does), and instead to use `define_method` in an initializer to generate the methods for our models.  This has the advantage that calling `.instance_methods` on a model class includes all the fields present in the content model.

We also took advantage of Rails' naming conventions to automatically infer the content type name based on the class name.  Thus in our code, we have `app/models/page.rb` which defines `class Page << WCC::Contentful::Model::Page`, and is automatically linked to the `page` content type ID.  (Note: this is overridable on a per-model basis)

All our models are automatically generated at startup which improves response times at the expense of initialization time.  In addition, our content model registry allows easy definition of custom models in your `app/models` directory to override fields.  This plays nice with other gems like algoliasearch-rails, which allows you to declaratively manage your Algolia indexes.  Another example from our flagship watermark.org:

```rb
class Page < WCC::Contentful::Model::Page
  include AlgoliaSearch

  algoliasearch(index_name: 'pages') do
    attribute(:title, :slug)
    ...
  end
```

### Automatic Pagination and Link Resolution

Using the `contentful_model` gem, calling `Page.all.load` does not give you all Page entries if there are more than 100.  To get the next page you must call `.paginate` on the response.  By contrast, `Page.find_all` in the `wcc-contentful` gem gives you a [Lazy Enumerator](https://ruby-doc.org/core-2.5.0/Enumerator/Lazy.html).  As you iterate past the 100th entry, the enumerator will automatically fetch the next page.  If you only enumerate 99 entries (say with `.take(99)`), then the second page will never be fetched.

Similarly, if your Page references an asset, say `hero_image`, that field returns a `Link` object rather than the actual `Asset`.  You must either predefine how many links you need using `Page.load_children(3).all.load`, or detect that `hero_image` is a `Link` like `if @page.hero_image.is_a? Contentful::Link` and then call `.resolve` on the link.  We found all of that to be too cumbersome when we are down in a nested partial view template that may be invoked from multiple places.

The `wcc-contentful` gem, by contrast, automatically resolves a link when accessing the associated attribute.  So in our example above, `wcc-contentful` will **always** return a `WCC::Contentful::Asset` when calling `@page.hero_image`, even if it has to execute a query to cdn.contentful.com in order to fetch it.

Warning: This can easily lead to you exhausting your Contentful API quota if you do not carefully tune your cache, which you should be doing anyways!  The default settings will use the Rails cache to try to cache these resolutions, but *you are ultimately responsible for how many queries you execute!*

### Automatic webhook management

The `wcc-contentful` gem, just like `contentful_rails`, provides an Engine to be mounted in your Rails routes file.  Unlike `contentful_rails`, if you also configure `wcc-contentful` with a Contentful Management Token and a public `app_url`, then on startup the `wcc-contentful` engine will reach out to the Contentful Management API and ensure that a webhook is configured to point to your app.  This is one less devops burden on you, and plays very nicely in with Heroku review apps.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wcc-contentful', require: 'wcc/contentful/rails'
```

If you're not using rails, exclude the `require:` parameter.

```ruby
gem 'wcc-contentful'
```

And then execute:

```
$ bundle
```

Or install it yourself:

```
$ gem install wcc-contentful
```

## Configure

Put this in an initializer:

```ruby
# config/initializers/wcc_contentful.rb
WCC::Contentful.configure do |config|
  config.access_token = <CONTENTFUL_ACCESS_TOKEN>
  config.space = <CONTENTFUL_SPACE_ID>
end

WCC::Contentful.init!
```

All configuration options can be found [in the rubydoc under
WCC::Contentful::Configuration](https://watermarkchurch.github.io/wcc-contentful/latest/wcc-contentful/WCC/Contentful/Configuration) 

## Usage

### WCC::Contentful::Model API

The WCC::Contentful::Model API exposes Contentful data as a set of dynamically
generated Ruby objects.  These objects are based on the content types in your
Contentful space.  All these objects are generated by `WCC::Contentful.init!`

The following examples show how to use this API to find entries of the `page`
content type:

```ruby
# Find objects by id
WCC::Contentful::Model::Page.find('1E2ucWSdacxxf233sfa3')
# => #<WCC::Contentful::Model::Page:0x0000000005c71a78 @created_at=2018-04-16 18:41:17 UTC...>

# Find objects by field
WCC::Contentful::Model::Page.find_by(slug: '/some-slug')
# => #<WCC::Contentful::Model::Page:0x0000000005c71a78 @created_at=2018-04-16 18:41:17 UTC...>

# Use operators to filter by a field
# must use full notation for sys attributes (except ID)
WCC::Contentful::Model::Page.find_all('sys.created_at' => { lte: Date.today })
# => [#<WCC::Contentful::Model::Page:0x0000000005c71a78 @created_at=2018-04-16 18:41:17 UTC...>, ... ]

# Nest queries to mimick joins
WCC::Contentful::Model::Page.find_by(subpages: { slug: '/some-slug' })
# => #<WCC::Contentful::Model::Page:0x0000000005c71a78 @created_at=2018-04-16 18:41:17 UTC...>

# Pass the preview flag to use the preview client (must have set preview_token config param)
preview_redirect = WCC::Contentful::Model::Redirect.find_by({ slug: 'draft-redirect' }, preview: true)
# => #<WCC::Contentful::Model::Redirect:0x0000000005d879ad @created_at=2018-04-16 18:41:17 UTC...>
preview_redirect_object.href
# => 'http://www.somesite.com/slug-for-redirect'
```

See the {WCC::Contentful::Model} documentation for more details.

### Store API

The Store layer is used by the Model API to access Contentful data in a raw form.
The Store layer returns entries as hashes parsed from JSON, conforming to the
object structure returned from the Contentful CDN.

The following examples show how to use the Store API to retrieve raw data from
the store:

```ruby
store = WCC::Contentful::Services.instance.store
# => #<WCC::Contentful::Store::CDNAdapter:0x00007fb92a221498

store.find('5FsqsbMECsM62e04U8sY4Y')
# => {"sys"=>
#  ...
# "fields"=>
# ...}

store.find_by(content_type: 'page', filter: { slug: '/some-slug' })
# => {"sys"=>
#  ...
# "fields"=>
# ...}

query = store.find_all(content_type: 'page').eq('group', 'some-group')
# => #<WCC::Contentful::Store::CDNAdapter::Query:0x00007fa3d40b84f0
query.first
# => {"sys"=>
#  ...
# "fields"=>
# ...}
query.result
# => #<Enumerator::Lazy: ...>
query.result.force
# => [{"sys"=> ...}, {"sys"=> ...}, ...]
```

See the {WCC::Contentful::Store} documentation for more details.

### Direct CDN API (SimpleClient)

The SimpleClient is the bottom layer, and is used to get raw data directly from
the Contentful CDN.  It handles response parsing and paging, but does not resolve
links or transform the result into a Model class.

The following examples show how to use the SimpleClient to retrieve data directly
from the Contentful CDN:

```ruby
client = WCC::Contentful::Services.instance.client
# => #<WCC::Contentful::SimpleClient::Cdn:0x00007fa3cde89310

response = client.entry('5FsqsbMECsM62e04U8sY4Y')
# => #<WCC::Contentful::SimpleClient::Response:0x00007fa3d103a4e0
response.body
# => "{\n  \"sys\": {\n ...
response.raw
# => {"sys"=>
#  ...
# "fields"=>
# ...}

client.asset('5FsqsbMECsM62e04U8sY4Y').raw
# => {"sys"=>
#  ...
# "fields"=>
# ...}

response = client.entries('fields.group' => 'some-group', 'limit' => 5)
# => #<WCC::Contentful::SimpleClient::Response:0x00007fa3d103a4e0
response.count
# => 99
response.first
# => {"sys"=>
#  ...
# "fields"=>
# ...}
response.items
=> #<Enumerator::Lazy: ...>
response.items.count  # Careful! This evaluates the lazy iterator and gets all pages
# => 99

response.includes
# => {"4xNnFJ77egkSMEogE2yISa"=>
#   {"sys"=> ...}
#  "6Fwukxxkxa6qQCC04WCaqg"=>
#   {"sys"=> ...}
#   ...}
```

The client handles Paging automatically within the lazy iterator returned by #items.
This lazy iterator does not respect the `limit` param - that param is only passed
through to the API to set the page size.  If you truly want a limited subset of
response items, use [`response.items.take(n)`](https://ruby-doc.org/core-2.5.3/Enumerable.html#method-i-take)

Entries included via the `include` parameter are made available on the #includes
field.  This is a hash of `<entry ID> => <raw entry>` and makes it easy to grab
links.  This hash is added to lazily as you enumerate the pages.

See the {WCC::Contentful::SimpleClient} documentation for more details.

### Accessing the APIs within application code

The Model API is best exposed by defining your own model classes in the `app/models`
directory which inherit from the WCC::Contentful models.

```ruby
# app/models/page.rb
class Page < WCC::Contentful::Model::Page

  # You can add additional methods here
end

# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  def show
    @page = Page.find_by(slug: params[:slug])
    raise Exceptions::PageNotFoundError, params[:slug] unless @page
  end
end
```

The {WCC::Contentful::Services} singleton gives access to the other configured services.
You can also include the {WCC::Contentful::ServiceAccessors} concern to define these
services as attributes in a class.

```ruby
class MyJob < ApplicationJob
  include WCC::Contentful::ServiceAccessors

  def perform
    Page.find(...)

    store.find(...)

    client.entries(...)
  end
end
```

## Architecture

![wcc-contentful diagram](./doc-static/wcc-contentful.png)

## Test Helpers

To use the test helpers, include the following in your rails_helper.rb:

```ruby
require 'wcc/contentful/rspec'
```

This adds the following helpers to all your specs:

```ruby
##
# Builds a in-memory instance of the Contentful model for the given content_type.
# All attributes that are known to be required fields on the content type
# will return a default value based on the field type.
instance = contentful_create('my-content-type', my_field: 'some-value')
# => #<WCC::Contentful::Model::MyContentType:0x0000000005c71a78 @created_at=2018-04-16 18:41:17 UTC...>

instance.my_field
# => "some-value"

instance.other_required_field
# => "default-value"

instance.other_optional_field
# => nil

instance.not_a_field
# NoMethodError: undefined method `not_a_field' for #<MyContentType:0x00007fbac81ee490>

##
# Builds a rspec double of the Contentful model for the given content_type.
# All attributes that are known to be required fields on the content type
# will return a default value based on the field type.
dbl = contentful_double('my-content-type', my_field: 'other-value')
# => #<Double (anonymous)>

dbl.my_field
# => "other-value"

dbl.other_optional_field
# => nil

dbl.not_a_field
# => #<Double (anonymous)> received unexpected message :not_a_field with (no args)

##
# Builds out a fake Contentful entry for the given content type, and then
# stubs the Model API to return that content type for `.find` and `.find_by`
# query methods.
stubbed = contentful_stub('my-content-type', id: '1234', my_field: 'test')

WCC::Contentful::Model.find('1234') == stubbed
# => true

MyContentType.find('1234') == stubbed
# => true

MyContentType.find_by(my_field: 'test') == stubbed
# => true
```

## Advanced Configuration Example

Here's an example containing all the configuration options, and a sample setup for
automatic deployment to Heroku.  This is intended to make you aware of what is possible,
and not as a general recommendation of what your setup should look like.

```ruby
# config/initializers/wcc_contentful.rb
WCC::Contentful.configure do |config|
  config.access_token = ENV['CONTENTFUL_ACCESS_TOKEN']
  config.space = ENV['CONTENTFUL_SPACE_ID']
  config.environment = ENV['CONTENTFUL_ENVIRONMENT']
  config.preview_token = ENV['CONTENTFUL_PREVIEW_ACCESS_TOKEN']

  # You may or may not want to provide this to your production server...
  config.management_token = ENV['CONTENTFUL_MANAGEMENT_TOKEN'] unless Rails.env.production?

  config.app_url = "https://#{ENV['HOSTNAME']}"
  config.webhook_username = 'my-app-webhook'
  config.webhook_password = Rails.application.secrets.webhook_password
  config.webhook_jobs << MyOnWebhookJob

  config.store = :lazy_sync, Rails.cache if Rails.env.production?
  # config.store = MyCustomStore.new

  # Use a custom Faraday connection
  config.connection = Faraday.new do |builder|
    f.request :retry
    f.request MyFaradayRequestAdapter.new
    ...
  end
  # OR implement some adapter like this to use another HTTP client
  config.connection = MyNetHttpAdapter.new

  config.update_schema_file = :never
end

WCC::Contentful.init!
```

For Heroku:

```yaml
# Procfile
web: bundle exec rails s
worker: bundle exec sidekiq
release: bin/release
```

```sh
# bin/release
#!/bin/sh

set -e

echo "Migrating database..."
bin/rake db:migrate

echo "Migrating contentful..."
migrations_to_be_run=$( ... ) # somehow figure this out
node_modules/.bin/contentful-migration \
    -s $CONTENTFUL_SPACE_ID -a $CONTENTFUL_MANAGEMENT_TOKEN \
    -y -p "$migrations_to_be_run"

echo "Updating schema file..."
rake wcc_contentful:download_schema
```

All configuration options can be found [in the rubydoc](https://www.rubydoc.info/gems/wcc-contentful/WCC/Contentful/Configuration) under
{WCC::Contentful::Configuration}


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/watermarkchurch/wcc-contentful.

The developers at Watermark Community Church have pledged to govern their interactions with each other, with their clients, and with the larger wcc-contentful user community in accordance with the "instruments of good works" from chapter 4 of The Rule of St. Benedict (hereafter: "The Rule"). This code of ethics has proven its mettle in thousands of diverse communities for over 1,500 years, and has served as a baseline for many civil law codes since the time of Charlemagne.

[See the full Code of Ethics](https://github.com/watermarkchurch/wcc-contentful/blob/master/CODE_OF_ETHICS.md)

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

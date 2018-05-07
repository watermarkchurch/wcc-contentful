# WCC::Contentful

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wcc-contentful', require: 'wcc/contentful/rails'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wcc-contentful

## Configure

```ruby
WCC::Contentful.configure do |config|
  config.access_token = <CONTENTFUL_ACCESS_TOKEN>
  config.preview_token = <CONTENTFUL_PREVIEW_TOKEN>
  config.space = <CONTENTFUL_SPACE_ID>
  config.default_locale = "en-US"
end

WCC::Contentful.init!
```

## Usage

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

# Pass the preview flag to use the preview client
preview_redirect = WCC::Contentful::Model::Redirect.find_by({ slug: 'draft-redirect' }, preview: true)
# => #<WCC::Contentful::Model::Redirect:0x0000000005d879ad @created_at=2018-04-16 18:41:17 UTC...>
preview_redirect_object.href
# => 'http://www.somesite.com/slug-for-redirect'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/wcc-contentful. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the WCC::Contentful project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/wcc-contentful/blob/master/CODE_OF_CONDUCT.md).

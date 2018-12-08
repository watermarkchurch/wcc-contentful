The home of multiple gems that Watermark Community Church uses to integrate with
Contentful.

[![Build Status](https://travis-ci.org/watermarkchurch/wcc-contentful.svg?branch=master)](https://travis-ci.org/watermarkchurch/wcc-contentful)
[![Coverage Status](https://coveralls.io/repos/github/watermarkchurch/wcc-contentful/badge.svg?branch=master)](https://coveralls.io/github/watermarkchurch/wcc-contentful?branch=master)

* [wcc-contentful](./wcc-contentful) [![Gem Version](https://badge.fury.io/rb/wcc-contentful.svg)](https://rubygems.org/gems/wcc-contentful)
* [wcc-contentful-app](./wcc-contentful-app) [![Gem Version](https://badge.fury.io/rb/wcc-contentful-app.svg)](https://rubygems.org/gems/wcc-contentful-app)

## Supported Rails versions

Please see the [most recent Travis-CI build](https://travis-ci.org/watermarkchurch/wcc-contentful) for the most
up-to-date list of supported Rails versions.  At the time of this writing, the gem officially supports
the following:

* Ruby versions:
  * 2.5
  * 2.3
* Rails versions:
  * 5.2
  * 5.0

Pull requests are welcome to enable supporting other ruby and rails versions!

To get started in testing a new Ruby version, use `rvm` or `rbenv` to choose your
rails version and then run all specs using the `bin/bundle` helper:

```bash
$ rbenv local 2.2.6
$ gem install bundler
$ bundle install
$ bin/bundle exec rspec
```

To get started testing a new rails version, add the appropriate combination of gems to the `Appraisals` file
and run `bundle exec appraisal install` to generate the appropriate gemfile in the `gemfiles` directory.
Then you can use the `bin/bundle` helper to run tests, while setting the BUNDLE_GEMFILE:

```bash
$ bundle exec appraisal install
$ BUNDLE_GEMFILE=`pwd`/gemfiles/rails_4.2.gemfile bin/bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/watermarkchurch/wcc-contentful. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the WCC::Contentful project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/watermarkchurch/wcc-contentful/blob/master/CODE_OF_CONDUCT.md).

## Deployment instructions:

1) Bump the version number using the appropriate rake task:

```
rake bump:major
rake bump:patch
rake bump:minor
rake bump:pre
```

Note: ensure that the versions of both gems are synchronized!  The release command
will run `rake check` and will fail if this is not the case.  The bump tasks should
synchronize automatically.

2) Run `rake release` to commit, tag, and upload the gems.

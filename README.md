The home of multiple gems that Watermark Community Church uses to integrate with
Contentful.

[![Build Status](https://travis-ci.org/watermarkchurch/wcc-contentful.svg?branch=master)](https://travis-ci.org/watermarkchurch/wcc-contentful)
[![Coverage Status](https://coveralls.io/repos/github/watermarkchurch/wcc-contentful/badge.svg?branch=master)](https://coveralls.io/github/watermarkchurch/wcc-contentful?branch=master)

* [wcc-contentful](./wcc-contentful) [![Gem Version](https://badge.fury.io/rb/wcc-contentful.svg)](https://rubygems.org/gems/wcc-contentful)
* [wcc-contentful-app](./wcc-contentful-app) [![Gem Version](https://badge.fury.io/rb/wcc-contentful-app.svg)](https://rubygems.org/gems/wcc-contentful-app)
* [wcc-contentful-graphql](./wcc-contentful-app) [![Gem Version](https://badge.fury.io/rb/wcc-contentful-graphql.svg)](https://rubygems.org/gems/wcc-contentful-graphql)

## Supported Rails versions

Please see the [most recent Travis-CI build](https://travis-ci.org/watermarkchurch/wcc-contentful) for the most
up-to-date list of supported framework environments.  At the time of this writing, 
the gem officially supports the following:

* Ruby versions:
  * 2.5
  * 2.3
* Framework versions:
  * Rails 5.2
  * Rails 5.0
  * Middleman 4.2

Pull requests are welcome to enable supporting other frameworks!

To get started in testing a new Ruby version, use `rvm` or `rbenv` to choose your
ruby version.  Then, check out the appropriate Gemfile using the `bin/use` helper:

```bash
$ rbenv local 2.2.6
$ gem install bundler
$ bundle install
$ bin/use gemfiles/rails_5.2.gemfile
```

Now each of the `wcc-` gems has a Gemfile based on that Appraisal gemfile.  `cd`
into the gem's directory and run `bundle install` to install the gems. 

### Adding a new Rails version

To get started testing a new framework, add the appropriate combination of gems to the `Appraisals` file
and run `bundle exec appraisal install` to generate the appropriate gemfile in the `gemfiles` directory:

```diff
diff --git a/Appraisals b/Appraisals
index 041abea..917142f 100644
--- a/Appraisals
+++ b/Appraisals
@@ -1,5 +1,9 @@
 # frozen_string_literal: true
 
+appraise 'sinatra-2.0' do
+  gem 'sinatra', '~> 2.0.0'
+end
+
 appraise 'rails-5.2' do
   gem 'rails', '~> 5.2.0'
   gem 'railties', '~> 5.2.0'
```

Then you can use the `bin/use` helper to check out that set of gems:

```bash
$ bundle exec appraisal install
$ bin/use gemfiles/rails_6.0.gemfile
```

And build a helper that conditionally includes your framework specs based on whether
that gem is installed.  Example:

```rb
# spec/active_record_helper.rb

require 'spec_helper'

begin
  gem 'activerecord'
  require 'active_record'
rescue Gem::LoadError => e
  # active_record is not loaded in this test run
  warn "WARNING: Cannot load active_record - some tests will be skipped\n#{e}"
end

if defined?(ActiveJob)
  ActiveJob::Base.queue_adapter = :test
else
  RSpec.configure do |c|
    # skip active record based specs
    c.before(:each, active_record: true) do
      skip 'activerecord is not loaded'
    end
  end
end

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

The home of multiple gems that Watermark Community Church uses to integrate with
Contentful.

[![Build Status](https://circleci.com/gh/watermarkchurch/wcc-contentful.svg?style=svg)](https://circleci.com/gh/watermarkchurch/wcc-contentful)
[![Coverage Status](https://coveralls.io/repos/github/watermarkchurch/wcc-contentful/badge.svg?branch=master)](https://coveralls.io/github/watermarkchurch/wcc-contentful?branch=master)

* [wcc-contentful](./wcc-contentful) [![Gem Version](https://badge.fury.io/rb/wcc-contentful.svg)](https://rubygems.org/gems/wcc-contentful)
* [wcc-contentful-middleman](./wcc-contentful-middleman) [![Gem Version](https://badge.fury.io/rb/wcc-contentful-middleman.svg)](https://rubygems.org/gems/wcc-contentful-middleman)
* [wcc-contentful-graphql](./wcc-contentful-graphql) [![Gem Version](https://badge.fury.io/rb/wcc-contentful-graphql.svg)](https://rubygems.org/gems/wcc-contentful-graphql)

## Supported Rails versions

Please see the [most recent CircleCI build](https://app.circleci.com/pipelines/github/watermarkchurch/wcc-contentful?branch=master) for the most
up-to-date list of supported framework environments.  At the time of this writing, 
the gem officially supports the following:

* Ruby versions:
  * 3.1
  * 2.7
* Framework versions:
  * Rails 6.1
  * Rails 5.2
  * Middleman 4.2

Pull requests are welcome to enable supporting other frameworks!

To get started in testing a new Ruby version, use `rvm` or `rbenv` to choose your
ruby version.  Then, check out the appropriate Gemfile using the `bin/use` helper:

```bash
$ rbenv local 3.1.1
$ gem install bundler
$ bundle install
$ bin/use gemfiles/rails_6.1_ruby_3.1.gemfile
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
 appraise 'rails-6.1' do
   gem 'rails', '~> 6.1'
   gem 'railties', '~> 6.1'
```

Then you can use the `bin/use` helper to check out that set of gems:

```bash
$ bundle exec appraisal install
$ bin/use gemfiles/rails_6.1.gemfile
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

## Code of Ethics

The developers at Watermark Community Church have pledged to govern their interactions with each other, with their clients, and with the larger wcc-contentful user community in accordance with the "instruments of good works" from chapter 4 of The Rule of St. Benedict (hereafter: "The Rule"). This code of ethics has proven its mettle in thousands of diverse communities for over 1,500 years, and has served as a baseline for many civil law codes since the time of Charlemagne.

[See the full Code of Ethics](./CODE_OF_ETHICS.md)


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

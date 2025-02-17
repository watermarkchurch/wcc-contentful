The home of multiple gems that Watermark Community Church uses to integrate with
Contentful.

[![Build Status](https://circleci.com/gh/watermarkchurch/wcc-contentful.svg?style=svg)](https://circleci.com/gh/watermarkchurch/wcc-contentful)
[![Coverage Status](https://coveralls.io/repos/github/watermarkchurch/wcc-contentful/badge.svg?branch=master)](https://coveralls.io/github/watermarkchurch/wcc-contentful?branch=master)

* [wcc-contentful](./wcc-contentful) [![Gem Version](https://badge.fury.io/rb/wcc-contentful.svg)](https://rubygems.org/gems/wcc-contentful)
* [(DEPRECATED) wcc-contentful-middleman](https://watermarkchurch.github.io/wcc-contentful/1.6/wcc-contentful-middleman/) [![Gem Version](https://badge.fury.io/rb/wcc-contentful-middleman.svg)](https://rubygems.org/gems/wcc-contentful-middleman)
* [(DEPRECATED) wcc-contentful-graphql](https://watermarkchurch.github.io/wcc-contentful/1.2/wcc-contentful-graphql/) [![Gem Version](https://badge.fury.io/rb/wcc-contentful-graphql.svg)](https://rubygems.org/gems/wcc-contentful-graphql)

## Supported Rails versions

Please see the [most recent CircleCI build](https://app.circleci.com/pipelines/github/watermarkchurch/wcc-contentful?branch=master) for the most
up-to-date list of supported framework environments.  At the time of this writing, 
the gem officially supports the following:

* Ruby versions:
  * 3.1 - 3.4
  * 2.7
* Framework versions:
  * Rails 8.0
  * Rails 7.0
  * Rails 6.1
  * Rack 2 (w/o Rails)

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
and run `bundle exec appraisal generate` to generate the appropriate gemfile in the `gemfiles` directory:

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
$ bundle exec appraisal generate
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

unless defined?(ActiveRecord)
  RSpec.configure do |c|
    # skip active record based specs
    c.before(:each, active_record: true) do
      skip 'activerecord is not loaded'
    end
  end
end

```

Finally, make sure you add it to the build matrix in `.circleci/config.yml`:

```diff
diff --git a/.circleci/config.yml b/.circleci/config.yml
index 317cde6..f5c439f 100644
--- a/.circleci/config.yml
+++ b/.circleci/config.yml
@@ -107,6 +107,10 @@ workflows:
           name: test_rails-7.2_ruby-3.3
           ruby: 3.3.5
           gemfile: gemfiles/rails_7.2_ruby_3.3.gemfile
+      - test:
+          name: sinatra-2.0_ruby-3.3
+          ruby: 3.3.5
+          gemfile: gemfiles/sinatra_2.0_ruby_3.3.gemfile
       - lint:
           ruby: 3.3.5
           gemfile: gemfiles/rails_7.2_ruby_3.3.gemfile
```

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

## v0.0.1

* initial release

## v0.0.2

* Will now return nil if the Redirect model's pageReference does not include a url
* Add test coverage for the Configuration class
* Add tests for the valid_page_reference? method

## v0.0.3

* Can now fetch Redirect models via slug, regardless of slug lettercase (uppercase or lowercase).

# v0.1.0

* Models are built dynamically from downloading the content_types via Contentful CDN
* 'Menu' and 'MenuItem' are defined and their structures are enforced via validation
* A GraphQL schema can optionally be generated to execute queries against Contentful

# v0.2.0

* Application models can be registered to be instantiated for a given content type
* New 'lazy sync' delivery method acts as a cache that is kept up to date by the sync API
* 'eager sync' is now hooked up to a webhook which can be mounted to receive publish events
* Major changes to configuration methods

# v0.3.0

* Now neccesary to require the engine in a Gemfile when using in Rails:

  `gem 'wcc-contentful', require: 'wcc/contentful/rails'`
  
* The gem can be configured to point to a non-master environment with the following configuration parameter:

  `config.environment = 'my_environment'`
  
* When a model is not found in contentful, `Model.find_by` returns `nil` rather than raising an error.

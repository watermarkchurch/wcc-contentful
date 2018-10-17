# Changelog

## v0.3.0

* Now neccesary to require the engine in a Gemfile when using in Rails:

  `gem 'wcc-contentful', require: 'wcc/contentful/rails'`
  
* The gem can be configured to point to a non-master environment with the following configuration parameter:

  `config.environment = 'my_environment'`
  
* When a model is not found in contentful, `Model.find_by` returns `nil` rather than raising an error.

* #78 lazy sync store fix @gburgett merged 2018-09-25
  Fixes an error found on staging, handling broken links together with cached data
  
  refs https://github.com/watermarkchurch/watermarkresources.com/pull/262

* #77 fix json blob array to h @gburgett merged 2018-09-20
  * Handle case of to_h on a json array

* #76 Remove date parsing @gburgett merged 2018-09-20
  

* #75 Wmresources 465 fix to h @gburgett merged 2018-09-20
  * `to_h` now invokes the defined attribute readers on the model class in order to get fields.
  * `to_h` no longer includes raw data deeper than the currently resolved depth on the model. 
  
  refs https://github.com/watermarkchurch/watermarkresources.com/issues/465

* #65 Allow using lazy_sync on non-master environment @gburgett merged 2018-09-20
  refs https://github.com/watermarkchurch/watermarkresources.com/pull/262

* #73 Removed old validation that prevented environments when using sync stores @reidcooper merged 2018-09-08
  

* #72 Pass arguments correctly to DelayedSyncJob in sync_later! @chasetopher merged 2018-08-17
  In `DelayedSyncJob#sync_later!`, the String `up_to_id` is being passed to the job instead of a Hash.
  
  Included a failing spec.

* #68 environments in client ext @gburgett merged 2018-08-14
  * Rewrite URLs to point to configured environment

* #63 Fix Delayed Sync Job when an JSON parse error is thrown when fetching the sync:token @reidcooper merged 2018-08-06
  Issue: https://github.com/watermarkchurch/wcc-contentful/issues/62

* #66 Support for side-by-side Contentful gem @reidcooper merged 2018-08-06
  https://github.com/watermarkchurch/wcc-contentful/issues/57

* #64 Fix Syntax Issue where Postgress requires parameters listed in function name, effects only pre version 10 @reidcooper merged 2018-08-06
  I am running into issues when running my specs on SemaphoreCI.
  
  There supported version of Postgres is 9.6.6, https://semaphoreci.com/docs/supported-stack.html
  
  According to this [Stackoverflow post](https://stackoverflow.com/questions/30782925/postgresql-how-to-drop-function-if-exists-without-specifying-parameters), Postgres 10 does not require the parameters listed when trying to drop a function. 
  
  However, for the sake of compatibility, I would like to add the parameters to the drop function.
  

* #58 Connection Options supported for Postgres store @reidcooper merged 2018-07-19
  

* #59 fix for .first method on postgress store resulting in invalid tuple number 0 @CollinSchneider merged 2018-07-17
  When using the Postgres data store, calling `find_by(some_field: "some-field-that-does-not-exist")` results in an `<ArgumentError: invalid tuple number 0>` due to the `.first` method not returning in time if `result.num_tuples.zero?` as it is designed in the other methods such as `find`, `delete`, `set`

* #54 Several minor fixes in support of watermark resources @gburgett merged 2018-07-13
  * Additional specs proving the correctness of the circular reference detection
  * Improve mime type registration to appropriately classify Contentful mime-types as an alias of application/json
  
  refs https://github.com/watermarkchurch/watermarkresources.com/issues/217

* #53 Add option to ignore circular references @gburgett merged 2018-06-28
  Model#resolve now accepts additional options to determine how to handle circular references.
  
  Valid values are `:raise` and `:ignore`.  On a circular reference, the former will raise an error while the latter will leave the link un-resolved.

* #51 Doc @gburgett merged 2018-06-27
  Fix some documentation for YARD format and connect it to rubydoc.info

* #50 Resource helpers @gburgett merged 2018-06-22
  Some additional utility methods on models related to this: https://zube.io/watermarkchurch/development/c/2304 (https://github.com/watermarkchurch/watermarkresources.com/issues/41)
  
  Features:
  * `resolve` now makes use of the Include param added in #47 in order to resolve to the given depth in the most efficient way possible
  * A new method `resolved?` was added to model objects which checks whether links have been resolved to a given depth
  * Every model now keeps track of the context that was given when it was found via `find` or `find_by` and exposes this on `sys.context`
  * The context exposes a new field `sys.context.backlinks` which is an array of the parent models from which this model was resolved.
  Example:
  ```
  pry(main)> page = c.main_navigation.items[0].link
  => #<Page:0x00007ff2366e61f0>
  pry(main)> page.sys.context.backlinks
  => [#<MenuButton:0x00007ff22d907de8>, #<Menu:0x00007ff22d3ac218>, #<SiteConfig:0x00007ff23404b388>]
  ```
  * Model links now expose the ID of the linked entry via `#{field.name}_id`, similar to ActiveRecord's representation of foreign key columns
  
  Bug Fixes:
  * Model implementation auto-loading no longer suppresses NameErrors within the model class defs
  * WebhookEnableJob is now only dropped in production
  * `to_h` now returns a hash with string keys, so the resulting hash representation is more similar to json
  
  Documentation:
  * Much RDoc, very wow
  * Readme.md now includes examples for using the store and client layers of the API via the new `Services` singleton.
  * Convenience methods were added to the CDNAdapter to make it more consistent with other store implementations for the `eq` query

* #49 Algolia integration @gburgett merged 2018-06-07
  Minor changes necessary to enable https://github.com/watermarkchurch/watermarkresources.com/pull/142

* #47 Resolve links via include param in contentful query @gburgett merged 2018-06-07
  Hooks up the [Include query param](https://www.contentful.com/developers/docs/references/content-delivery-api/#/reference/links/retrieval-of-linked-items) to `Model.find_by`, and automatically resolves links that are given in the query response by the `includes` array.
  
  fixes #38 

* #46 Facilitate attaching jobs to be run whenever a webhook is received @gburgett merged 2018-06-05
  The gem can now be configured with additional jobs to be run whenever the mounted engine receives a webhook at `/webhooks/receive`.  If the job is an ActiveJob class, then `perform_later` will be called with the raw event JSON as it's only parameter.  Otherwise if the job responds to `call`, it will be immediately invoked with the raw event JSON.
  
  Syntax:
  ```ruby
  # initializers/wcc_contentful.rb
  WCC::Contentful.configure do |config|
    # ...
    config.webhook_jobs << MyJobClass
    config.webhook_jobs << ->(event) { ... }
  end
  ```
  
  The gem now automatically configures a webhook to point to the correct URL on the app, if given a `management_token` and `app_url`.
  
  fixes #39 

* #43 Model name collisions @gburgett merged 2018-05-24
  The Model registry no longer attempts to instantiate an applications' ActiveRecord model classes as though they were Contentful model classes.  This allows the app to define an ActiveRecord model, ex. `Menu`, that collides with a content type in their space.  They will refer to the ActiveRecord model by it's non-namespaced name, and the content type by it's namespaced name ex. `WCC::Contentful::Model::Menu`.

* #36 Provide a standard way to dump a model object to json @gburgett merged 2018-05-16
  * Adds a recursive resolve method
  * Overrides standard to_json so that the JSON dump will have fields resolved properly

* #34 Menu updates @gburgett merged 2018-05-09
  Improvements to wcc-contentful gem to facilitate https://github.com/watermarkchurch/watermarkresources.com/issues/56

* #32 adds ability to nest CDN query conditions @jpowell merged 2018-05-07
  closes #30 

* #33 Raise ArgumentError if client uses preview without proper configuration @rorJeremy merged 2018-05-02
  Right now, if a user makes a 'find_by' call to the preview api using the gem without having first configured the gem with a contentful preview token, you'll get a 500 NoMethodError that says you can't use find_by on Nil. This PR just raises an error for that scenario that explains the situation a little more clear.

## v0.2.2

* Add preview_client for doing contentful calls to their preview api
* 'find_by' can now receive a preview param set to a boolean value 
* Can configure your preview_api by passing a preview_token to configure block
* The Redirect model provides a 'href' method that will give you the url it points to

## v0.2.0

* Application models can be registered to be instantiated for a given content type
* New 'lazy sync' delivery method acts as a cache that is kept up to date by the sync API
* 'eager sync' is now hooked up to a webhook which can be mounted to receive publish events
* Major changes to configuration methods

## v0.1.0

* Models are built dynamically from downloading the content_types via Contentful CDN
* 'Menu' and 'MenuItem' are defined and their structures are enforced via validation
* A GraphQL schema can optionally be generated to execute queries against Contentful

## v0.0.3

* Can now fetch Redirect models via slug, regardless of slug lettercase (uppercase or lowercase).

## v0.0.2

* Will now return nil if the Redirect model's pageReference does not include a url
* Add test coverage for the Configuration class
* Add tests for the valid_page_reference? method

## v0.0.1

* initial release

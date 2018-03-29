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
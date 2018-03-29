# frozen_string_literal: true

# This file reopens the "Menu" class which was dynamically
# created by the WCC::Contentful gem.  This class does not need to do anything,
# the attributes have already been defined based on the `content_type` returned
# from the Contentful API.  However you can reopen the class to add functionality.
class WCC::Contentful::Model::Menu < WCC::Contentful::Model

  # Add custom validations to ensure that app-specific properties exist:
  # validate_field :foo, :String, :required
  # validate_field :bar_links, :Array, link_to: %w[bar baz]

  # Override functionality or add utilities
  #
  # # Example: override equality
  # def ===(other)
  #   ...
  # end
  #
  # # Example: override "name" attribute to always be camelized.
  # #          `@name` is populated by the gem in the initializer.
  # def name
  #   @name_camelized ||= @name.camelize(true)
  # end
end

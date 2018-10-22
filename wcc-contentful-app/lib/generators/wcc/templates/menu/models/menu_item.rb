# frozen_string_literal: true

# This model represents the 'menuItem' content type in Contentful.  Any linked
# entries of the 'menuItem' content type will be resolved as instances of this class.
# It exposes #find, #find_by, and #find_all methods to query Contentful.
class MenuItem < WCC::Contentful::Model::MenuItem
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
  # # Example: override "title" attribute to always be camelized.
  # #          `@title` is populated by the gem in the initializer.
  # def title
  #   @title_camelized ||= @title.camelize(true)
  # end
end

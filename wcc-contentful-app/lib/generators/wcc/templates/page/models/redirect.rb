# frozen_string_literal: true
 # This model represents the 'redirect' content type in Contentful.  Any linked
# entries of the 'redirect' content type will be resolved as instances of this class.
# It exposes .find, .find_by, and .find_all methods to query Contentful.
class Redirect < WCC::Contentful::Model::Redirect
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
  # # Example: override "title" attribute to always be titlecase.
  # #          `@title` is populated by the gem in the initializer.
  # def title
  #   @title_titlecased ||= @title.titlecase
  # end
end

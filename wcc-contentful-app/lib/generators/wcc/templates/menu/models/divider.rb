# frozen_string_literal: true

# This model represents the 'divider' content type in Contentful.  Any linked
# entries of the 'divider' content type will be resolved as instances of this class.
# It exposes #find, #find_by, and #find_all methods to query Contentful.
class Divider < WCC::Contentful::Model::Divider
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

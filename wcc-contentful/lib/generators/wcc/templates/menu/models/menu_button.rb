# frozen_string_literal: true

# This model represents the 'menuButton' content type in Contentful.  Any linked
# entries of the 'menuButton' content type will be resolved as instances of this class.
# It exposes #find, #find_by, and #find_all methods to query Contentful.
class MenuButton < WCC::Contentful::Model::MenuButton
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
  # # Example: override "text" attribute to always be camelized.
  # #          `@text` is populated by the gem in the initializer.
  # def text
  #   @text_camelized ||= @text.camelize(true)
  # end
end

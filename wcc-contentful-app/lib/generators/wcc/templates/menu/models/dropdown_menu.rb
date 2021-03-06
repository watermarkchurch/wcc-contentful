# frozen_string_literal: true

# This model represents the 'dropdownMenu' content type in Contentful.  Any linked
# entries of the 'dropdownMenu' content type will be resolved as instances of this class.
# It exposes #find, #find_by, and #find_all methods to query Contentful.
class DropdownMenu < WCC::Contentful::Model::DropdownMenu
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

# frozen_string_literal: true

# This model represents the 'site-config' content type in Contentful.  Any linked
# entries of the 'site-config' content type will be resolved as instances of this class.
# It exposes .find, .find_by, and .find_all methods to query Contentful.
class SiteConfig < WCC::Contentful::Model::SiteConfig
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

# frozen_string_literal: true

# This model represents the 'section-video-highlight' content type in Contentful.  Any linked
# entries of the 'section-video-highlight' content type will be resolved as instances of this class.
# It exposes .find, .find_by, and .find_all methods to query Contentful.
class SectionVideoHighlight < WCC::Contentful::Model::SectionVideoHighlight
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

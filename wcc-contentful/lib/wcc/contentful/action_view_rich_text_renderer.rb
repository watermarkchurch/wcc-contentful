# frozen_string_literal: true

require 'action_view'

# An implementation of the RichTextRenderer that uses ActionView helpers to implement content_tag and concat.
class WCC::Contentful::ActionViewRichTextRenderer < WCC::Contentful::RichTextRenderer
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Context

  # TODO: use ActionView view context to render ERB templates for embedded entries?
end

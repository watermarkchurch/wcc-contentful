# frozen_string_literal: true

require 'action_view'

class WCC::Contentful::ActionViewRichTextRenderer < WCC::Contentful::RichTextRenderer
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Context
end

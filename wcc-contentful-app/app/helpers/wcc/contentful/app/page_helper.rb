# frozen_string_literal: true

module WCC::Contentful::App::PageHelper
  def render_section(section, index)
    render('components/section', section: section, index: index)
  end
end

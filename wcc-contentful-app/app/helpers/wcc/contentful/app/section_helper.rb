# frozen_string_literal: true

require 'redcarpet'

module WCC::Contentful::App::SectionHelper
  extend self

  def section_template_name(section)
    section.class.name.demodulize.underscore.sub('section_', '')
  end

  def section_css_name(section)
    section_template_name(section).dasherize
  end

  def section_styles(section)
    section_styles = ['section-' + section_css_name(section)]
    if styles = section.try(:styles)
      section_styles.push(styles.map { |style| style.downcase.gsub(/[^\w]/, '-') })
    elsif style = section.try(:style)
      section_styles.push(style.downcase.gsub(/[^\w]/, '-'))
    else
      section_styles.push('default')
    end
    section_styles
  end

  def section_id(section)
    title = section.try(:bookmark_title) || section.try(:title)
    CGI.escape(title.gsub(/\W+/, '-')) if title.present?
  end

  def markdown(text)
    options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: 'nofollow', target: '_blank' },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: true,
      tables: true
    }

    renderer = ::Redcarpet::Render::HTML.new(options)
    markdown = ::Redcarpet::Markdown.new(renderer, extensions)

    markdown.render(text).html_safe
  end

  def safe_line_break(text)
    return unless text.present?

    text = CGI.escapeHTML(text)
    text = text.gsub(/\&amp;(nbsp|vert|\#\d+);/, '&\1;')
      .gsub(/\&lt;br\/?\&gt;/, '<br/>')
    content_tag(:span, text.html_safe, class: 'safe-line-break')
  end

  def split_content_for_mobile_view(visible_count, speakers)
    visible_count = visible_count.to_i
    speakers = [*speakers].compact
    [speakers.shift(visible_count), speakers]
  end
end

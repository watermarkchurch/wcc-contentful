# frozen_string_literal: true

require 'redcarpet'

module WCC::Contentful::App::SectionHelper
  extend self

  def render_section(section, index)
    render('components/section', section: section, index: index)
  end

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
    raise ArgumentError, 'markdown method requires text' unless text

    markdown_links = links_within_markdown(text)
    links_with_classes, raw_classes = gather_links_with_classes_data(markdown_links)

    options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { target: '_blank' },
      space_after_headers: true,
      fenced_code_blocks: true,
      links_with_classes: links_with_classes
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: true,
      tables: true
    }

    renderer = ::WCC::Contentful::App::CustomMarkdownRender.new(options)
    markdown = ::Redcarpet::Markdown.new(renderer, extensions)
    html_to_render = markdown.render(remove_markdown_href_class_syntax(raw_classes, text))

    content_tag(:div,
      CGI.unescapeHTML(html_to_render).html_safe,
      class: 'formatted-content')
  end

  def links_within_markdown(text)
    text.scan(/(\[(.*?)\]\((.*?)\)(\{\:.*?\})?)/)
  end

  def gather_links_with_classes_data(markdown_links)
    links_with_classes_arr = []
    raw_classes_arr = []
    markdown_links.each do |markdown_link_arr|
      next unless markdown_link_arr.last.present?

      raw_class = markdown_link_arr[3]
      url, title = url_and_title(markdown_link_arr[2])
      content = markdown_link_arr[1]
      classes = capture_individual_classes(raw_class)
      link_class = combine_individual_classes_to_one_string(classes)

      raw_classes_arr << raw_class
      links_with_classes_arr << [url, title, content, link_class]
    end

    [links_with_classes_arr, raw_classes_arr]
  end

  def remove_markdown_href_class_syntax(raw_classes, text)
    text_without_markdown_class_syntax = text.dup
    raw_classes.each { |klass| text_without_markdown_class_syntax.slice!(klass) }
    text_without_markdown_class_syntax
  end

  def url_and_title(markdown_link_and_title)
    match =
      markdown_link_and_title.scan(
        /(\s|^)(https?:\/\/\S*|^\/\S*\/*\S*|^#\S*|mailto:\S*)(?=\s|$)|(\".*?\")/
      )
    url = match[0][1]
    title = match[1] ? match[1][2] : nil
    [url, title]
  end

  def capture_individual_classes(classes)
    classes.scan(/\.[^\.\}\s]*/)
  end

  def combine_individual_classes_to_one_string(classes)
    class_string = ''
    classes.each do |klass|
      class_string += klass.tr('.', '') + ' '
    end
    class_string
  end

  def safe_line_break(text, options = {})
    return unless text.present?

    text = CGI.escapeHTML(text)
    text = text.gsub(/\&amp;(nbsp|vert|\#\d+);/, '&\1;')
      .gsub(/\&lt;br\/?\&gt;/, '<br/>')
    content_tag(:span, text.html_safe, {
      class: 'safe-line-break'
    }.merge(options))
  end

  def split_content_for_mobile_view(visible_count, speakers)
    visible_count = visible_count.to_i
    speakers = [*speakers].compact
    [speakers.shift(visible_count), speakers]
  end
end

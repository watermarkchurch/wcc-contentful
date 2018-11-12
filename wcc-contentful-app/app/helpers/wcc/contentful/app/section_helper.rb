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
    markdown_links = links_within_markdown(text)
    links_with_classes, raw_classes = gather_links_with_classes_data(markdown_links)

    options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: 'nofollow', target: '_blank' },
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

    if links_with_classes.present?
      renderer = ::WCC::Contentful::App::CustomMarkdownRender.new(options)
      remove_markdown_href_class_syntax(raw_classes, text)
    else
      renderer = ::Redcarpet::Render::HTML.new(options)
    end

    markdown = ::Redcarpet::Markdown.new(renderer, extensions)

    markdown.render(text).html_safe
  end

  def links_within_markdown(text)  
    # Captures all of the links in the markdown text provided
    # with each matching link being returned as an array like the following:
    # [
    #   '[button text](http://www.watermark.org "Watermark Church"){: .button .white}',
    #   'button text',
    #   'http://www.watermark.org "Watermark Church"',
    #   '{: .button .white}'
    # ]
    text.scan(/(\[(.*?)\]\((.*?)\)(\{\:.*?\})?)/)
  end

  def gather_links_with_classes_data(markdown_links)
    # If the markdown has links in it then we will iterate over
    # those links. Each link is an array of 4 values. The last value
    # in one of the link arrays is where we store the classes for that
    # link, if it has any. And if it does, we will store the details
    # of that link in the 'links_with_classes_arr' and then use it
    # later in the CustomMarkdownRender to actually add the classes
    # to the link as we're building it.
    links_with_classes_arr = []
    raw_classes_arr = []
    return [links_with_classes_arr, raw_classes_arr] unless markdown_links.present?
    markdown_links.each do |markdown_link_arr|
      if markdown_link_arr.last.present?
        raw_class = markdown_link_arr[3]
        url, title = url_and_title(markdown_link_arr[2])
        content = markdown_link_arr[1]
        classes = capture_individual_classes(raw_class)
        link_class = combine_individual_classes_to_one_string(classes)

        raw_classes_arr << raw_class
        links_with_classes_arr << [url, title, content, link_class]
      end
    end

    [links_with_classes_arr, raw_classes_arr]
  end

  def remove_markdown_href_class_syntax(raw_classes, text)
    # remove all of the '{: .button}' syntax from the markdown text
    # so that it doesn't get rendered to the page
    raw_classes.each { |klass| text.slice!(klass) }
  end

  def url_and_title(markdown_link_and_title)
    # match markdown styled absolute or relative url and title if provided
    match = markdown_link_and_title.scan(/(\s|^)(https?:\/\/\S*)|(^\/\S*\/*\S*)(?=\s|$)|(\".*?\")/)
    url = match[0][1]
    title = match[1] ? match[1][2] : nil
    [url, title]
  end

  def capture_individual_classes(classes)
    # receives the '{: .button .white}' class syntax
    # then returns the classes as an array
    # ['.button', '.white']
    classes.scan(/[.][\S]*[^\}\s]/)
  end

  def combine_individual_classes_to_one_string(classes)
    # converts an array of classes
    # ['.button', '.white']
    # into one string to be used as the class for a url tag
    # 'button white'
    class_string = ""    
    classes.each do |klass|
      class_string += klass.tr('.', '') + ' '
    end
    class_string
  end

  def safe_line_break(text)
    return unless text.present?

    text = CGI.escapeHTML(text)
    text = text.gsub(/\&amp;(nbsp|vert|\#\d+);/, '&\1;')
      .gsub(/\&lt;br\/?\&gt;/, '<br/>')
    text.html_safe
  end

  def split_content_for_mobile_view(visible_count, speakers)
    visible_count = visible_count.to_i
    speakers = [*speakers].compact
    [speakers.shift(visible_count), speakers]
  end
end

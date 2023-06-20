# frozen_string_literal: true

require_relative './custom_markdown_render'

class WCC::Contentful::App::MarkdownRenderer
  attr_reader :options, :extensions

  def initialize(options = nil)
    options = options&.dup

    @extensions = {
      autolink: true,
      superscript: true,
      strikethrough: true,
      disable_indented_code_blocks: true,
      tables: true
    }.merge!(options&.delete(:extensions) || {})

    @options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { target: '_blank' },
      space_after_headers: true,
      fenced_code_blocks: true
    }.merge!(options || {})
  end

  def markdown(text)
    raise ArgumentError, 'markdown method requires text' unless text

    markdown_links = links_within_markdown(text)
    links_with_classes, raw_classes = gather_links_with_classes_data(markdown_links)

    options = @options.merge({
      links_with_classes: links_with_classes
    })

    renderer = ::WCC::Contentful::App::CustomMarkdownRender.new(options)
    markdown = ::Redcarpet::Markdown.new(renderer, extensions)
    markdown.render(remove_markdown_href_class_syntax(raw_classes, text))
  end

  alias_method :call, :markdown

  private

  def remove_markdown_href_class_syntax(raw_classes, text)
    text_without_markdown_class_syntax = text.dup
    raw_classes.each { |klass| text_without_markdown_class_syntax.slice!(klass) }
    text_without_markdown_class_syntax
  end

  def links_within_markdown(text)
    text.scan(/(\[(.*?)\]\((.*?)\)(\{:.*?\})?)/)
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

  def url_and_title(markdown_link_and_title)
    match =
      markdown_link_and_title.scan(
        /(\s|^)(https?:\/\/\S*|^\/\S*\/*\S*|^#\S*|mailto:\S*)(?=\s|$)|(".*?")/
      )
    url = match[0][1]
    title = match[1] ? match[1][2] : nil
    [url, title]
  end

  def capture_individual_classes(classes)
    classes.scan(/\.[^.}\s]*/)
  end

  def combine_individual_classes_to_one_string(classes)
    class_string = ''
    classes.each do |klass|
      class_string += "#{klass.tr('.', '')} "
    end
    class_string
  end
end

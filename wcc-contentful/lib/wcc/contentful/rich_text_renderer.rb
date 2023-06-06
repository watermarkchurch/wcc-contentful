# frozen_string_literal: true

class WCC::Contentful::RichTextRenderer
  class << self
    attr_writer :implementation_class

    def implementation_class
      @implementation_class ||
        WCC::Contentful.configuration&.rich_text_renderer ||
        load_implementation_class
    end

    def new(document)
      return super unless self == WCC::Contentful::RichTextRenderer

      unless implementation_class
        raise NotImplementedError,
          'No rich text renderer implementation has been configured.  ' \
          'Please install a supported implementation such as ActionView, ' \
          'or set WCC::Contentful.configuration.rich_text_renderer to a custom implementation.'
      end

      implementation_class.new(document)
    end

    def call(document)
      new(document).to_html
    end

    private

    def load_implementation_class
      # More implementations?

      require 'wcc/contentful/rich_text_renderer/action_view_rich_text_renderer'
      WCC::Contentful::ActionViewRichTextRenderer
    rescue LoadError
      nil
    end
  end

  attr_reader :document

  def initialize(document)
    @document = document
  end

  def render
    content_tag(:div, class: 'contentful-rich-text') do
      document.content.each do |node|
        concat render_node(node)
      end
    end
  end

  def render_node(node)
    case node.node_type
    when /heading-(\d+)/
      render_heading(node)
    else
      public_send(:"render_#{node.node_type.underscore}", node)
    end
  end

  def render_text(node)
    content_tag(:span, node.value)
  end

  def render_paragraph(node)
    content_tag(:p) do
      node.content.each do |child|
        concat render_node(child)
      end
    end
  end

  def render_heading(node)
    content_tag(:"h#{node.size}") do
      node.content.each do |child|
        concat render_node(child)
      end
    end
  end

  def to_html
    render.to_s
  end

  private

  def content_tag(*_args)
    raise NotImplementedError, 'RichTextRenderer is an abstract class, please use an implementation subclass'
  end

  def concat(*_args)
    raise NotImplementedError, 'RichTextRenderer is an abstract class, please use an implementation subclass'
  end
end

require 'wcc/contentful/rich_text_renderer/action_view_rich_text_renderer' if defined?(ActionView)

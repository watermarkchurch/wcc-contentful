# frozen_string_literal: true

class WCC::Contentful::RichTextRenderer
  class << self
    attr_writer :implementation_class

    def implementation_class
      @implementation_class ||
        WCC::Contentful.configuration&.rich_text_renderer ||
        load_implementation_class
    end

    def new(*args, **kwargs)
      return super unless self == WCC::Contentful::RichTextRenderer

      unless implementation_class
        raise NotImplementedError,
          'No rich text renderer implementation has been configured.  ' \
          'Please install a supported implementation such as ActionView, ' \
          'or set WCC::Contentful.configuration.rich_text_renderer to a custom implementation.'
      end

      implementation_class.new(*args, **kwargs)
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

  def store
    @store ||= WCC::Contentful::Services.instance.store
  end

  def config
    @config ||= WCC::Contentful.configuration
  end

  def model_api
    @model_api ||= WCC::Contentful::Model
  end

  def initialize(document, config: nil, store: nil, model_api: nil)
    @document = document
    @config = config
    @store = store
    @model_api = model_api
  end

  def render
    content_tag(:div, class: 'contentful-rich-text') do
      render_content(document.content)
    end
  end

  def render_content(content)
    content&.each do |node|
      concat render_node(node)
    end
  end

  def render_node(node)
    if WCC::Contentful::RichText::Heading.matches?(node.node_type)
      render_heading(node)
    else
      public_send(:"render_#{node.node_type.underscore}", node)
    end
  end

  def render_text(node)
    return node.value unless node.marks&.any?

    node.marks.reduce(node.value) do |value, mark|
      next value unless type = mark['type']&.underscore

      render_mark(type, value)
    end
  end

  DEFAULT_MARKS = {
    'bold' => 'strong',
    'italic' => 'em',
    'underline' => 'u',
    'code' => 'code',
    'superscript' => 'sup',
    'subscript' => 'sub'
  }.freeze

  def render_mark(type, value)
    return value unless tag = DEFAULT_MARKS[type]

    content_tag(tag, value)
  end

  def render_paragraph(node)
    content_tag(:p) do
      render_content(node.content)
    end
  end

  def render_heading(node)
    content_tag(:"h#{node.size}") do
      render_content(node.content)
    end
  end

  def render_blockquote(node)
    content_tag(:blockquote) do
      render_content(node.content)
    end
  end

  def render_hr(_node)
    content_tag(:hr)
  end

  def render_unordered_list(node)
    content_tag(:ul) do
      render_content(node.content)
    end
  end

  def render_ordered_list(node)
    content_tag(:ol) do
      render_content(node.content)
    end
  end

  def render_list_item(node)
    content_tag(:li) do
      render_content(node.content)
    end
  end

  def render_table(node)
    content_tag(:table) do
      render_content(node.content)
    end
  end

  def render_table_row(node)
    content_tag(:tr) do
      render_content(node.content)
    end
  end

  def render_table_cell(node)
    content_tag(:td) do
      render_content(node.content)
    end
  end

  def render_table_header_cell(node)
    content_tag(:th) do
      render_content(node.content)
    end
  end

  def render_hyperlink(node)
    content_tag(:a,
      href: node.data['uri'],
      # External links should be target="_blank" by default
      target: ('_blank' if url_is_external?(node.data['uri']))) do
      render_content(node.content)
    end
  end

  def render_asset_hyperlink(node)
    target = resolve_target(node.data['target'])
    url = target&.dig('fields', 'file', 'url')

    render_hyperlink(
      WCC::Contentful::RichText::Hyperlink.tokenize(
        node.as_json.merge(
          'nodeType' => 'hyperlink',
          'data' => node['data'].merge({
            'uri' => url,
            'target' => target.as_json
          })
        )
      )
    )
  end

  def render_entry_hyperlink(node)
    target = resolve_target(node.data['target'])
    model_instance = model_api.new_from_raw(target)
    unless model_instance.respond_to?(:href)
      raise NotImplementedError,
        "Entry hyperlinks are not supported for #{model_instance.class}.  " \
        'Please ensure your model defines an #href method, or override the ' \
        '#render_entry_hyperlink method in your app-specific RichTextRenderer implementation.'
    end

    render_hyperlink(
      WCC::Contentful::RichText::Hyperlink.tokenize(
        node.as_json.merge(
          'nodeType' => 'hyperlink',
          'data' => node['data'].merge({
            'uri' => model_instance.href,
            'target' => target.as_json
          })
        )
      )
    )
  end

  def render_embedded_asset_block(node)
    target = resolve_target(node.data['target'])
    title = target&.dig('fields', 'title')
    url = target&.dig('fields', 'file', 'url')

    content_tag(:img, src: url, alt: title) do
      render_content(node.content)
    end
  end

  def render_embedded_entry_block(node)
    raise NotImplementedError,
      'Entry embeds are not supported.  What should it look like? ' \
      'Please override this in your app-specific RichTextRenderer implementation.'
  end

  def render_embedded_entry_inline(node)
    raise NotImplementedError,
      'Inline Entry embeds are not supported.  What should it look like? ' \
      'Please override this in your app-specific RichTextRenderer implementation.'
  end

  def to_html
    render.to_s
  end

  private

  def resolve_target(target)
    if target&.dig('sys', 'type') == 'Link'
      target = store.find(target.dig('sys', 'id'), hint: target.dig('sys', 'linkType'))
    end
    target
  end

  def url_is_external?(url)
    return false unless url.present?

    uri =
      begin
        URI(url)
      rescue StandardError
        nil
      end
    return false unless uri&.host.present?

    app_uri =
      begin
        URI(config.app_url)
      rescue StandardError
        nil
      end
    uri.host != app_uri&.host
  end

  def content_tag(*_args)
    raise NotImplementedError, 'RichTextRenderer is an abstract class, please use an implementation subclass'
  end

  def concat(*_args)
    raise NotImplementedError, 'RichTextRenderer is an abstract class, please use an implementation subclass'
  end
end

require 'wcc/contentful/rich_text_renderer/action_view_rich_text_renderer' if defined?(ActionView)

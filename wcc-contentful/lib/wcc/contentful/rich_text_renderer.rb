# frozen_string_literal: true

class WCC::Contentful::RichTextRenderer
  class << self
    def call(document, *args, **kwargs)
      new(document, *args, **kwargs).call
    end
  end

  attr_reader :document
  attr_accessor :config, :store, :model_namespace

  def initialize(document)
    @document = document
  end

  def call
    render.to_s
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
      # Check the first row - if it's a header row, render a <thead>
      first, *rest = node.content
      if first&.content&.all? { |cell| cell.node_type == 'table-header-cell' }
        concat(content_tag(:thead) { render_content([first]) })
      else
        # Otherwise, render it inside the tbody with the rest
        rest.unshift(first)
      end

      concat(content_tag(:tbody) { render_content(rest) })
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
    unless model_api.present?
      raise NotConnectedError,
        'Rendering linked entries requires a connected RichTextRenderer.  Please use the one configured in ' \
        'WCC::Contentful::Services.instance or pass a model_api to the RichTextRenderer constructor.'
    end

    target = resolve_target(node.data['target'])
    model_instance = model_api.new_from_raw(target)
    unless model_instance.respond_to?(:href)
      raise NotConnectedError,
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

  def render_embedded_entry_block(_node)
    raise AbstractRendererError,
      'Entry embeds are not supported.  What should it look like? ' \
      'Please override this in your app-specific RichTextRenderer implementation.'
  end

  def render_embedded_entry_inline(_node)
    raise AbstractRendererError,
      'Inline Entry embeds are not supported.  What should it look like? ' \
      'Please override this in your app-specific RichTextRenderer implementation.'
  end

  private

  def resolve_target(target)
    unless store.present?
      raise NotConnectedError,
        'Rendering embedded or linked entries requires a connected RichTextRenderer.  Please use the one configured ' \
        'in WCC::Contentful::Services.instance or pass a store to the RichTextRenderer constructor.'
    end

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
      if config&.app_url.present?
        begin
          URI(config.app_url)
        rescue StandardError
          nil
        end
      end
    uri.host != app_uri&.host
  end

  def content_tag(*_args)
    raise AbstractRendererError, 'RichTextRenderer is an abstract class, please use an implementation subclass'
  end

  def concat(*_args)
    raise AbstractRendererError, 'RichTextRenderer is an abstract class, please use an implementation subclass'
  end

  class AbstractRendererError < StandardError
  end

  class NotConnectedError < AbstractRendererError
  end
end

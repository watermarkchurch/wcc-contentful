# frozen_string_literal: true

module WCC::Contentful::App::MenuHelper
  def dropdown?(item)
    item.respond_to?(:items)
  end

  def item_active?(item)
    return true if item.try(:label) && item_active?(item.label)
    return item.items.any? { |i| item_active?(i) } if item.respond_to?(:items)
    return current_page?(item.href) if item.try(:href)
    false
  end

  def render_button(button, options = {}, &block)
    html = render_button_inner_html(button, options, &block)

    if button.external?
      push_class('external', options)
      options[:target] = :_blank
    end
    push_class('icon-only', options) unless button.text.present?

    push_class(button.style, options) if button.style

    href = button.href
    href = hash_only(href) if href.present? && local?(href)
    return link_to(html, href, options) if href.present?
    content_tag(:a, html, options)
  end

  def render_button_inner_html(button, options = {}, &block)
    html = render_button_icon(button.icon, options.delete(:icon)) ||
      render_button_material_icon(button.material_icon) + content_tag(:span, button.text)

    html += capture(&block) if block_given?
    html
  end

  def render_button_icon(icon, options = {})
    fallback = options&.delete(:fallback)
    return fallback&.call unless icon

    options = {
      alt: icon.description || icon.title,
      width: icon.file.dig('details', 'image', 'width'),
      height: icon.file.dig('details', 'image', 'height'),
    }.merge!(options || {})
    image_tag(icon&.file&.url, options)
  end

  def render_button_material_icon(material_icon)
    content_tag(:i, material_icon&.downcase, class: ['material-icons'])
  end

  def push_class(classes, options)
    options[:class] = [*classes].push(*options[:class])
  end

  def hash_only(href)
    url = URI(href)
    '#' + url.fragment if url.fragment.present?
  end

  # An href is local if it points to a part of the page
  def local?(href)
    return true if href =~ /^#/
    url = URI(href)
    return false unless url.fragment.present?
    fragment = url.fragment
    url.fragment = nil
    current_page?(url.to_s)
  end
end

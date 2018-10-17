# frozen_string_literal: true

module WCC::Contentful::App::MenuHelper
  extend self
  DYNAMIC_BUTTONS = %w[loginButton cartButton].freeze

  def main_navigation
    global_site_config.main_navigation
  end

  def utility_navigation
    global_site_config.utility_menu
  end

  def brand_button
    global_site_config.brand
  end

  def side_bar_menu
    global_site_config.side_bar_menu
  end

  def dropdown?(item)
    item.respond_to?(:items)
  end

  def dynamic_button?(button)
    return unless defined?(button.class.content_type)
    WCC::Contentful::App::MenuHelper::DYNAMIC_BUTTONS.include?(button.class.content_type)
  end

  def item_active?(item)
    return true if item.try(:label) && item_active?(item.label)
    return item.items.any? { |i| item_active?(i) } if item.respond_to?(:items)
    return current_page?(item.href) if item.try(:href)
    false
  end

  def icon_or_ion_icon(icon, ion_icon)
    render_button_icon(icon) || render_button_ion_icon(ion_icon)
  end

  def render_button(button, options = {}, &block)
    return unless button_permitted?(button)

    html = render_button_inner_html(button, options, &block)

    if button.external?
      push_class('external', options)
      options[:target] = :_blank
    end
    push_class('icon-only', options) unless button.text.present?

    push_class(button.style, options) if button.style

    return link_to(html, button.href, options) if button.href
    content_tag(:a, html, options)
  end

  def render_button_inner_html(button, options = {}, &block)
    html = render_button_icon(button.icon, options.delete(:icon)) ||
      render_button_ion_icon(button.ion_icon) + button.text

    html += capture(&block) if block_given?
    html
  end

  def render_button_icon(icon, options = {})
    fallback = options&.delete(:fallback)
    return fallback&.call unless icon

    options = {
      alt: icon.description || icon.title,
      width: icon.file.dig('details', 'image', 'width'),
      height: icon.file.dig('details', 'image', 'height')
    }.merge!(options || {})
    image_tag(icon&.file&.url, options)
  end

  def render_button_ion_icon(ion_icon)
    content_tag(:i, '', class: ['icon', ion_icon])
  end

  def push_class(classes, options)
    options[:class] = [*classes].push(*options[:class])
  end

  def button_permitted?(button)
    button.link.blank? || can?(:read, button.link)
  end
end

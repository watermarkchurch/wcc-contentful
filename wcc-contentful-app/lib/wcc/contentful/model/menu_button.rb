# frozen_string_literal: true

class WCC::Contentful::Model::MenuButton < WCC::Contentful::Model
  validate_field :text, :String, :required
  validate_field :icon, :Asset, :optional
  validate_field :external_link, :String, :optional
  validate_field :link, :Link, :optional, link_to: 'page'
  validate_field :section_link, :Link, :optional
  validate_field :style, :String, :required

  def external_uri
    @external_url ||= URI(external_link) if external_link.present?
  end

  # A menu link is external if `external_link` is present and not relative.
  def external?
    external_uri&.scheme.present?
  end

  # Gets either the external link or the slug from the referenced page.
  # Example usage: `<%= link_to button.title, button.href %>`
  def href
    return external_link if external_link
    url = (link&.try(:slug) || link&.try(:url))
    return url unless fragment.present?
    url = URI(url || '')
    url.fragment = fragment
    url.to_s
  end

  def fragment
    return unless (section = section_link&.try(:bookmark_title) || section_link&.try(:title)).present?
    CGI.escape(section.gsub(/\W+/,'-'))
  end
end

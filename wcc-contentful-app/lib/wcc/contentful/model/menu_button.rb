# frozen_string_literal: true

class WCC::Contentful::Model::MenuButton < WCC::Contentful::Model
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
    WCC::Contentful::App::SectionHelper.section_id(section_link) if section_link
  end
end

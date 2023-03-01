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
    url = URI(url || '')

    url = rewrite_to_locale(url, sys.locale) if default_locale && sys.locale != default_locale

    url.fragment = fragment if fragment.present?
    url.to_s
  end

  def fragment
    WCC::Contentful::App::SectionHelper.section_id(section_link) if section_link
  end

  private

  def default_locale
    WCC::Contentful.configuration&.default_locale
  end

  def rewrite_to_locale(uri, locale)
    uri = URI(uri)
    uri.path = File.join("/#{locale}", uri.path)
    uri.to_s
  end
end

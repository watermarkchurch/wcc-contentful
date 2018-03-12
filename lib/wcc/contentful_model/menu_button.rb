# frozen_string_literal: true

class WCC::ContentfulModel::MenuButton < WCC::ContentfulModel
  validate_field :title, :String, :required
  validate_field :external_link, :String, :optional
  validate_field :link, :optional, link_to: 'page'

  # Gets either the external link or the slug from the referenced page.
  # Example usage: `<%= link_to button.title, button.href %>`
  def href
    return external_link if external_link
    link&.try(:slug) || link&.try(:url)
  end
end

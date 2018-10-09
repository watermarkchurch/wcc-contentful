# frozen_string_literal: true

class WCC::Contentful::Model::Page < WCC::Contentful::Model
  validate_field :title, :String
  validate_field :slug, :String
  validate_field :subpages, :Array, link_to: %w[page]
  validate_field :sections, :Array, link_to: /^section/
end

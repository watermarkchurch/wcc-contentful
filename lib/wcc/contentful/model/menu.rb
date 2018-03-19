# frozen_string_literal: true

class WCC::Contentful::Model::Menu < WCC::Contentful::Model
  validate_field :name, :String
  validate_field :top_button, :Link, :optional, link_to: 'menuButton'
  validate_field :items, :Array, link_to: %w[menu menuButton]
end

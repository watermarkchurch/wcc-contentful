# frozen_string_literal: true

class WCC::Contentful::Model::Menu < WCC::Contentful::Model
  validate_field :name, :String
  validate_field :icon, :Asset, :optional
  validate_field :rootButton, :required, link_to: 'menuButton'
  validate_field :buttons, :Array, link_to: %w[menu menuButton]
end

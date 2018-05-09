# frozen_string_literal: true

class WCC::Contentful::Model::DropdownMenu < WCC::Contentful::Model
  validate_field :name, :String
  validate_field :label, :Link, link_to: 'menuButton'
  validate_field :items, :Array, link_to: 'menuButton'
end

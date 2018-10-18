# frozen_string_literal: true

class WCC::Contentful::Model::Menu < WCC::Contentful::Model
  validate_field :name, :String
  validate_field :items, :Array, link_to: %w[dropdownMenu menuButton dynamicButton]
end

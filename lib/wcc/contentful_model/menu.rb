# frozen_string_literal: true

class WCC::ContentfulModel::Menu < WCC::ContentfulModel
  validate_field :name, :String
  validate_field :icon, :Asset, :optional
  validate_field :first_group, :Array, link_to: %w[menu menuButton]
end

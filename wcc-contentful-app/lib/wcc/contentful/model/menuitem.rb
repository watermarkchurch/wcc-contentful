# frozen_string_literal: true

class WCC::Contentful::Model::Menuitem < WCC::Contentful::Model
  validate_field :title, :String, :required
  validate_field :submenu, :Array, link_to: %w[submenu]
  validate_field :url, :String, :required
  validate_field :page, :Entry, link_to: %w[blog event location page]
  validate_field :order, :Integer
end

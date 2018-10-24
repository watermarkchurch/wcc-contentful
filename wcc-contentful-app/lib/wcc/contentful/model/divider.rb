# frozen_string_literal: true

class WCC::Contentful::Model::Divider < WCC::Contentful::Model
  validate_field :style, :String, :required
end

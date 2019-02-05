# frozen_string_literal: true

class WCC::Contentful::Link
  attr_reader :id
  attr_reader :link_type
  attr_reader :raw

  LINK_TYPES = {
    Asset: 'Asset',
    Link: 'Entry'
  }.freeze

  def initialize(model, link_type = nil)
    @id = model.try(:id) || model
    @link_type = link_type
    @link_type ||= model.is_a?(WCC::Contentful::Model::Asset) ? :Asset : :Link
    @raw =
      {
        'sys' => {
          'type' => 'Link',
          'linkType' => LINK_TYPES[@link_type] || link_type,
          'id' => @id
        }
      }
  end

  alias_method :to_h, :raw
end

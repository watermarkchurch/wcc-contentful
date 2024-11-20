# frozen_string_literal: true

class WCC::Contentful::Link
  attr_reader :id, :link_type, :raw

  LINK_TYPES = {
    Asset: 'Asset',
    Link: 'Entry',
    Tag: 'Tag'
  }.freeze

  def initialize(model, link_type = nil)
    if model.is_a?(Hash)
      raise ArgumentError, 'Not a Link' unless model.dig('sys', 'type') == 'Link'

      @raw = model
      @id = model.dig('sys', 'id')
      @link_type = model.dig('sys', 'linkType')
    else
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
  end

  alias_method :to_h, :raw
end

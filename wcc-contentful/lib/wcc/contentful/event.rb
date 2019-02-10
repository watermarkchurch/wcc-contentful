# frozen_string_literal: true

class WCC::Contentful::Event
  def initialize(raw, context = nil)
    @raw = raw.freeze

    created_at = raw.dig('sys', 'createdAt')
    created_at = Time.parse(created_at) if created_at.present?
    updated_at = raw.dig('sys', 'updatedAt')
    updated_at = Time.parse(updated_at) if updated_at.present?
    @sys = WCC::Contentful::Sys.new(
      raw.dig('sys', 'id'),
      raw.dig('sys', 'type'),
      raw.dig('sys', 'locale') || context.try(:[], :locale) || 'en-US',
      raw.dig('sys', 'space', 'sys', 'id'),
      created_at,
      updated_at,
      raw.dig('sys', 'revision'),
      OpenStruct.new(context).freeze
    )
  end

  attr_reader :sys
  attr_reader :raw
  delegate :id, to: :sys
  delegate :type, to: :sys
  delegate :created_at, to: :sys
  delegate :updated_at, to: :sys
  delegate :revision, to: :sys
  delegate :space, to: :sys

  delegate :dig, :[], to: :raw

  class << self
    def from_raw(raw, context = nil)
      const = EVENT_TYPES[raw.dig('sys', 'type')]
      const ||= WCC::Contentful::Event::Unknown

      const.new(raw, context)
    end
  end

  class Entry < WCC::Contentful::Event
    def entry
      @entry ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
    end
  end

  class Asset < WCC::Contentful::Event
    def asset
      @asset ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
    end

    alias_method :entry, :asset
  end

  class DeletedEntry < WCC::Contentful::Event
    def entry
      @entry ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
    end
  end

  class DeletedAsset < WCC::Contentful::Event
    def asset
      @asset ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
    end

    alias_method :entry, :asset
  end

  class Unknown < WCC::Contentful::Event
  end

  EVENT_TYPES = {
    'Entry' => WCC::Contentful::Event::Entry,
    'Asset' => WCC::Contentful::Event::Asset,
    'DeletedEntry' => WCC::Contentful::Event::DeletedEntry,
    'DeletedAsset' => WCC::Contentful::Event::DeletedAsset
  }.freeze
end

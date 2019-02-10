# frozen_string_literal: true

module WCC::Contentful::Event
  extend ActiveSupport::Concern

  def self.from_raw(raw, context = nil)
    const = Registry.instance.get(raw.dig('sys', 'type'))

    const.new(raw, context)
  end

  class Registry
    include Singleton

    def get(name)
      @event_types ||= {}
      @event_types[name] || WCC::Contentful::Event::Unknown
    end

    def register(constant)
      name = constant.try(:type) || constant.name.demodulize
      unless constant.respond_to?(:new)
        raise ArgumentError, "Constant #{constant} does not define 'new'"
      end

      @event_types ||= {}
      @event_types[name] = constant
    end
  end

  included do
    Registry.instance.register(self)

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
  end
end

class WCC::Contentful::Event::Entry
  include WCC::Contentful::Event

  def entry
    @entry ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
  end
end

class WCC::Contentful::Event::Asset
  include WCC::Contentful::Event

  def asset
    @asset ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
  end

  alias_method :entry, :asset
end

class WCC::Contentful::Event::DeletedEntry
  include WCC::Contentful::Event

  def entry
    @entry ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
  end
end

class WCC::Contentful::Event::DeletedAsset
  include WCC::Contentful::Event

  def asset
    @asset ||= WCC::Contentful::Model.new_from_raw(raw, sys.context)
  end

  alias_method :entry, :asset
end

class WCC::Contentful::Event::Unknown
  include WCC::Contentful::Event
end

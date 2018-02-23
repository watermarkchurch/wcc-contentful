# frozen_string_literal: true

require 'singleton'
require 'graphql'

require_relative 'memory_store'

module WCC::Contentful::Graphql
  class Indexer
    include Singleton

    attr_reader :types
    attr_reader :store

    def initialize
      @store = MemoryStore.instance
      @types = {}
      @mutex = Mutex.new
    end

    def index(id, value)
      content_type_name = find_content_type_name(value)

      content_type = create_type_from_value(content_type_name, value)
      sync { @types[content_type.name] = merge(@types[content_type.name], content_type) }

      @store.index(id, value)
    end

    def create_type_from_value(name, value)
      content_type = OpenStruct.new({
        name: "Contentful#{name.camelize}",
        fields: {}
      })

      value.dig('fields').each do |f|
        field_name = f[0]
        first_localized_value = f[1].first[1]
        content_type.fields[field_name] = OpenStruct.new({
          name: field_name,
          type: find_field_type(first_localized_value)
        })
      end

      content_type
    end

    private

    def find_content_type_name(value)
      case value.dig('sys', 'type')
      when 'Entry'
        value.dig('sys', 'contentType', 'sys', 'id')
      when 'Asset'
        'Asset'
      else
        raise ArgumentError, "Unknown content type '#{value.dig('sys', 'type') || 'null'}'"
      end
    end

    # Float
    # String
    # Int
    # Boolean
    # ID
    def find_field_type(value)
      return :Boolean if value.in? [true, false]
      return :Int if value.is_a? Integer
      return :Float if value.is_a? Float
      if value.is_a? String
        return :DateTime if time?(value)
        return :String
      end

      if value.is_a? Hash
        return :Location if value['lon'].present?
        return :Asset if value.dig('sys', 'linkType') == 'Asset'
        return :Link if value.dig('sys', 'linkType') == 'Entry'
      end

      :Json
    end

    def merge(type_a, type_b)
      return type_b if type_a.nil?

      type_b.fields.each do |name, type|
        # Contentful only sends back fields that actually exist in the content type
        type_a.fields[name] = merge_field(type_a.fields[name], type)
      end
      type_a
    end

    def merge_field(field_a, field_b)
      return field_b if field_a.nil?

      # If the "float" happens to be an integer like '2.0'
      # Contentful will send back the integer '2' in the JSON response
      field_a.type = :Float if field_a.type == :Int && field_b.type == :Float

      field_a
    end

    def time?(value)
      Time.zone.parse(value)
    rescue ArgumentError
      false
    end

    def sync
      @mutex.synchronize do
        yield
      end
    end
  end
end

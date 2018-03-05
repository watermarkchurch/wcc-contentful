# frozen_string_literal: true

module WCC::Contentful::Sync
  class Indexer
    include WCC::Contentful::Helpers

    attr_reader :store

    def types
      @mutex.synchronize do
        resolve_links unless @links_resolved
        @links_resolved = true
      end
      @types.dup
    end

    def initialize(store = nil)
      @store = store || MemoryStore.new
      @types = {}
      @mutex = Mutex.new
    end

    def index(id, value)
      content_type_id = content_type_from_raw(value)

      content_type = create_type_from_value(content_type_id, value)
      content_type =
        @mutex.synchronize do
          @links_resolved = false
          @types[content_type[:name]] = merge(content_type, @types[content_type[:name]])
        end

      @store.index(id, value)
    end

    def create_type_from_value(content_type_id, value)
      content_type = {
        name: constant_from_content_type(content_type_id),
        content_type: content_type_id,
        fields: {}
      }

      value.dig('fields').each do |f|
        field_name = f[0]
        first_localized_value = f[1].first[1]
        field = {
          name: field_name,
          type: find_field_type(first_localized_value)
        }
        field[:link_id] = extract_link_ids(first_localized_value) if field[:type] == :Link
        field[:array] = true if first_localized_value.is_a? Array
        content_type[:fields][field_name] = field
      end

      content_type
    end

    private

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

      return find_field_type(value.first) if value.is_a? Array

      if value.is_a? Hash
        return :Coordinates if value['lon'].present?
        return :Asset if value.dig('sys', 'linkType') == 'Asset'
        return :Link if value.dig('sys', 'linkType') == 'Entry'
      end

      :Json
    end

    def merge(type_a, type_b)
      return type_a if type_b.nil?

      type_b[:fields].each do |name, type|
        # Contentful only sends back fields that actually exist in the content type
        type_a[:fields][name] = merge_field(type_a[:fields][name], type)
      end
      type_a
    end

    def merge_field(field_a, field_b)
      return field_b if field_a.nil?
      return field_a if field_b.nil?

      # If the "float" happens to be an integer like '2.0'
      # Contentful will send back the integer '2' in the JSON response
      field_a[:type] = :Float if field_a[:type] == :Int && field_b[:type] == :Float

      field_a[:array] = true if field_a[:array] || field_b[:array]

      field_a[:link_id] = (field_a[:link_id] || []) + (field_b[:link_id] || [])
      field_a[:link_id].uniq
      field_a
    end

    def extract_link_ids(field_value)
      return field_value.map { |v| v.dig('sys', 'id') } if field_value.is_a? Array
      [field_value.dig('sys', 'id')]
    end

    def resolve_links
      @types.each_value do |type_def|
        type_def[:fields].each do |(_, field)|
          next if field[:link_id].nil? || field[:link_id].empty?

          link_types =
            field[:link_id].map do |id|
              linked = @store.find(id)
              next unless linked.present?
              constant_from_content_type(
                content_type_from_raw(linked)
              )
            end

          if field[:link_types].nil?
            field[:link_types] = link_types
          else
            field[:link_types].push(*link_types)
          end
          field[:link_types].uniq!
          # this data is no longer necessary
          field[:link_id] = nil
        end
      end
    end

    # Handles known contentful dates - https://stackoverflow.com/questions/28020805/regex-validate-correct-iso8601-date-string-with-time
    # rubocop:disable Metrics/LineLength
    ISO8601 = /^(?:[1-9]\d{3}-(?:(?:0[1-9]|1[0-2])-(?:0[1-9]|1\d|2[0-8])|(?:0[13-9]|1[0-2])-(?:29|30)|(?:0[13578]|1[02])-31)|(?:[1-9]\d(?:0[48]|[2468][048]|[13579][26])|(?:[2468][048]|[13579][26])00)-02-29)T(?:[01]\d|2[0-3]):[0-5]\d(?:\:[0-5]\d)?(?:\.\d{1,9})?(?:Z|[+-][01]\d:[0-5]\d)?$/
    # rubocop:enable Metrics/LineLength
    def time?(value)
      value =~ ISO8601
    rescue ArgumentError
      false
    end
  end
end

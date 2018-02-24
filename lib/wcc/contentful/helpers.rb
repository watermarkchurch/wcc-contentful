
# frozen_string_literal: true

module WCC::Contentful::Helpers
  def content_type_from_raw(value)
    case value.dig('sys', 'type')
    when 'Entry'
      value.dig('sys', 'contentType', 'sys', 'id')
    when 'Asset'
      'Asset'
    else
      raise ArgumentError, "Unknown content type '#{value.dig('sys', 'type') || 'null'}'"
    end
  end

  def constant_from_content_type(content_type)
    content_type.camelize.gsub(/[^_a-zA-Z0-9]/, '_')
  end
end

# frozen_string_literal: true

module WCC::Contentful::Helpers
  extend self

  def content_type_from_raw(value)
    case value.dig('sys', 'type')
    when 'Entry', 'DeletedEntry'
      value.dig('sys', 'contentType', 'sys', 'id')
    when 'Asset', 'DeletedAsset'
      'Asset'
    else
      raise ArgumentError, "Unknown content type '#{value.dig('sys', 'type') || 'null'}'"
    end
  end

  def constant_from_content_type(content_type)
    content_type.gsub(/[^_a-zA-Z0-9]/, '_').camelize
  end

  def shared_prefix(string_array)
    string_array.reduce do |l, s|
      l = l.chop while l != s[0...l.length]
      l
    end
  end

  def content_type_from_constant(const)
    return const.content_type if const.respond_to?(:content_type)
    name = const.try(:name) || const.to_s
    name.demodulize.camelize(:lower)
  end
end

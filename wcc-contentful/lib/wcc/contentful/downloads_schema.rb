# frozen_string_literal: true

require 'wcc/contentful'

class WCC::Contentful::DownloadsSchema
  def self.call(file = nil, management_client: nil)
    new(file, management_client).call
  end

  def initialize(file = nil, management_client = nil)
    @client = management_client || WCC::Contentful::Services.instance.management_client
    @file = file || './db/contentful-schema.json'
  end

  def call
    return unless needs_update?

    update!
  end

  def update!
    FileUtils.mkdir_p(File.dirname(@file))

    File.write(@file, JSON.pretty_generate({
      'contentTypes' => content_types,
      'editorInterfaces' => editor_interfaces
    }))
  end

  def needs_update?
    return true unless File.exist?(@file)

    contents =
      begin
        JSON.parse(File.read(@file))
      rescue JSON::ParserError
        return true
      end

    existing_cts = contents['contentTypes'].sort_by { |ct| ct.dig('sys', 'id') }
    return true unless content_types.count == existing_cts.count
    return true unless deep_contains_all(content_types, existing_cts)

    existing_eis = contents['editorInterfaces'].sort_by { |i| i.dig('sys', 'contentType', 'sys', 'id') }
    return true unless editor_interfaces.count == existing_eis.count

    !deep_contains_all(editor_interfaces, existing_eis)
  end

  def content_types
    @content_types ||=
      @client.content_types(limit: 1000)
        .items
        .map { |ct| strip_sys(ct) }
        .sort_by { |ct| ct.dig('sys', 'id') }
  end

  def editor_interfaces
    @editor_interfaces ||=
      content_types
        .map { |ct| @client.editor_interface(ct.dig('sys', 'id')).raw }
        .map { |i| strip_sys(i) }
        .sort_by { |i| i.dig('sys', 'contentType', 'sys', 'id') }
  end

  private

  def strip_sys(obj)
    obj.merge!({
      'sys' => obj['sys'].slice('id', 'type', 'contentType')
    })
  end

  def deep_contains_all(expected, actual)
    if expected.is_a? Array
      expected.each_with_index do |val, i|
        return false unless deep_contains_all(val, actual[i])
      end
      true
    elsif expected.is_a? Hash
      expected.each do |(key, val)|
        return false unless actual.key?(key)
        return false unless deep_contains_all(val, actual[key])
      end
      true
    else
      expected == actual
    end
  end
end

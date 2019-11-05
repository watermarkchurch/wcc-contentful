# frozen_string_literal: true

require 'wcc/contentful'

class WCC::Contentful::DownloadsSchema
  def self.call(file = nil, management_client: nil)
    new(file, management_client: management_client).call
  end

  def initialize(file = nil, management_client: nil)
    @client = management_client || WCC::Contentful::Services.instance.management_client
    @file = file || WCC::Contentful.configuration&.schema_file
    raise ArgumentError, 'Please configure your management token' unless @client
    raise ArgumentError, 'Please pass filename or call WCC::Contentful.configure' unless @file
  end

  def call
    return unless needs_update?

    update!
  end

  def update!
    FileUtils.mkdir_p(File.dirname(@file))

    File.write(@file, format_json({
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
        .map { |i| sort_controls(strip_sys(i)) }
        .sort_by { |i| i.dig('sys', 'contentType', 'sys', 'id') }
  end

  private

  def strip_sys(obj)
    obj.merge!({
      'sys' => obj['sys'].slice('id', 'type', 'contentType')
    })
  end

  def sort_controls(editor_interface)
    {
      'sys' => editor_interface['sys'],
      'controls' => editor_interface['controls']
        .sort_by { |c| c['fieldId'] }
        .map { |c| c.slice('fieldId', 'settings', 'widgetId') }
    }
  end

  def deep_contains_all(expected, actual)
    if expected.is_a? Array
      expected.each_with_index do |val, i|
        return false unless actual[i]
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

  def format_json(hash)
    json_string = JSON.pretty_generate(hash)

    # The pretty_generate format differs from contentful-shell and nodejs formats
    # only in its treatment of empty arrays in the "validations" field.
    json_string = json_string.gsub(/\[\n\n\s+\]/, '[]')
    # contentful-shell also adds a newline at the end.
    json_string + "\n"
  end
end

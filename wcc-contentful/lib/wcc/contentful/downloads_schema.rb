# frozen_string_literal: true

class WCC::Contentful::DownloadsSchema
  def self.call(file = nil, management_client: nil)
    new(file, management_client).call
  end

  def initialize(file = nil, management_client = nil)
    @client = management_client || WCC::Contentful::Services.instance.management_client
    @file = file || './db/contentful-schema.json'
  end

  def call
    FileUtils.mkdir_p(File.dirname(@file))

    File.write(@file, JSON.pretty_generate({
      'contentTypes' => content_types,
      'editorInterfaces' => editor_interfaces
    }))
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
        .map { |ct| @client.editor_interface(ct.dig('sys', 'id')).body }
        .map { |i| strip_sys(i) }
        .sort_by { |i| i.dig('sys', 'contentType', 'sys', 'id') }
  end

  private

  def strip_sys(obj)
    obj.merge!({
      'sys' => obj['sys'].slice('id', 'type', 'contentType')
    })
  end
end

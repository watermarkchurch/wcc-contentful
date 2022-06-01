# frozen_string_literal: true

require_relative './rich_text/node'

module WCC::Contentful::RichText
  def self.tokenize(raw, context = nil)
    return unless raw
    return raw.map { |c| tokenize(c, context) } if raw.is_a?(Array)

    case raw['nodeType']
    when 'document'
      Document.tokenize(raw, context)
    when 'paragraph'
      Paragraph.tokenize(raw, context)
    when 'blockquote'
      Blockquote.tokenize(raw, context)
    when 'text'
      Text.new(raw['value'], raw['marks'], raw['data'])
    when 'embedded-entry-inline'
      EmbeddedEntryInline.tokenize(raw, context)
    when 'embedded-entry-block'
      EmbeddedEntryBlock.tokenize(raw, context)
    when 'embedded-asset-block'
      EmbeddedAssetBlock.tokenize(raw, context)
    when /heading\-(\d+)/
      size = Regexp.last_match(1)
      const_get("Heading#{size}").new(tokenize(raw['content']), raw['data'])
    else
      Unknown.tokenize(raw, context)
    end
  end

  Document =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end

  Paragraph =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end

  Blockquote =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end

  Text =
    Struct.new(:nodeType, :value, :marks, :data) do
      include WCC::Contentful::RichText::Node
    end

  EmbeddedEntryInline =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end

  EmbeddedEntryBlock =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end

  EmbeddedAssetBlock =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end

  (1..5).each do |i|
    struct =
      Struct.new(:nodeType, :data, :content) do
        include WCC::Contentful::RichText::Node
      end
    sz = i
    struct.define_method(:size) { sz }
    struct.define_singleton_method(:node_type) { "heading-#{sz}" }
    const_set("Heading#{sz}", struct)
  end

  Unknown =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end
end

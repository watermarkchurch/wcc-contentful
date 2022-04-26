# frozen_string_literal: true

module WCC::Contentful::RichText
  def self.tokenize(raw, context = nil)
    return unless raw
    return raw.map { |c| tokenize(c, context) } if raw.is_a?(Array)

    case raw['nodeType']
    when 'document'
      Document.new(tokenize(raw['content'], context), raw['data'])
    when 'paragraph'
      Paragraph.new(tokenize(raw['content'], context), raw['data'])
    when 'blockquote'
      Paragraph.new(tokenize(raw['content'], context), raw['data'])
    when 'text'
      Text.new(raw['value'], raw['marks'], raw['data'])
    when 'embedded-entry-inline'
      EmbeddedEntryInline.new(tokenize(raw['content'], context), raw['data'])
    when 'embedded-entry-block'
      EmbeddedEntryBlock.new(tokenize(raw['content'], context), raw['data'])
    when 'embedded-asset-block'
      EmbeddedAssetBlock.new(tokenize(raw['content'], context), raw['data'])
    when /heading\-(\d+)/
      Heading.new(Regexp.last_match(1), tokenize(raw['content']), raw['data'])
    else
      raise ArgumentError, "Unknown token '#{raw['content']}'"
    end
  end

  Document =
    Struct.new(:content, :data) do
      def node_type
        'document'
      end
    end

  Paragraph =
    Struct.new(:content, :data) do
      def node_type
        'paragraph'
      end
    end

  Blockquote =
    Struct.new(:content, :data) do
      def node_type
        'blockquote'
      end
    end

  Text =
    Struct.new(:value, :marks, :data) do
      def node_type
        'text'
      end
    end

  EmbeddedEntryInline =
    Struct.new(:content, :data) do
      def node_type
        'embedded-entry-inline'
      end
    end

  EmbeddedEntryBlock =
    Struct.new(:content, :data) do
      def node_type
        'embedded-entry-block'
      end
    end

  EmbeddedAssetBlock =
    Struct.new(:content, :data) do
      def node_type
        'embedded-asset-block'
      end
    end

  Heading =
    Struct.new(:size, :content, :data) do
      def node_type
        "heading-#{size}"
      end
    end
end

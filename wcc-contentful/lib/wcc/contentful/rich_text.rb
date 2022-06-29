# frozen_string_literal: true

require_relative './rich_text/node'

##
# This module contains a number of structs representing nodes in a Contentful
# rich text field.  When the Model layer parses a Rich Text field from
# Contentful, it is turned into a WCC::Contentful::RichText::Document node.
# The {WCC::Contentful::RichText::Document#content content} method of this
# node is an Array containing paragraph, blockquote, entry, and other nodes.
#
# The various structs in the RichText object model are designed to mimic the
# Hash interface, so that the indexing operator `#[]` and the `#dig` method
# can be used to traverse the data.  The data can also be accessed by the
# attribute reader methods defined on the structs.  Both of these are considered
# part of the public API of the model and will not change.
#
# In a future release we plan to implement automatic link resolution.  When that
# happens, the `.data` attribute of embedded entries and assets will return a
# new class that is able to resolve the `.target` automatically into a full
# entry or asset.  This future class will still respect the hash accessor methods
# `#[]`, `#dig`, `#keys`, and `#each`, so it is safe to use those.
module WCC::Contentful::RichText
  ##
  # Recursively converts a raw JSON-parsed hash into the RichText object model.
  def self.tokenize(raw, context = nil)
    return unless raw
    return raw.map { |c| tokenize(c, context) } if raw.is_a?(Array)

    klass =
      case raw['nodeType']
      when 'document'
        Document
      when 'paragraph'
        Paragraph
      when 'blockquote'
        Blockquote
      when 'text'
        Text
      when 'embedded-entry-inline'
        EmbeddedEntryInline
      when 'embedded-entry-block'
        EmbeddedEntryBlock
      when 'embedded-asset-block'
        EmbeddedAssetBlock
      when /heading\-(\d+)/
        size = Regexp.last_match(1)
        const_get("Heading#{size}")
      else
        Unknown
      end

    klass.tokenize(raw, context)
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
    struct.define_singleton_method(:node_type) { "heading-#{sz}" }
    const_set("Heading#{sz}", struct)
  end

  Unknown =
    Struct.new(:nodeType, :data, :content) do
      include WCC::Contentful::RichText::Node
    end
end

# frozen_string_literal: true

module WCC::Contentful::RichText
  module Node
    extend ActiveSupport::Concern

    def keys
      members.map(&:to_s)
    end

    included do
      include Enumerable

      alias_method :node_type, :nodeType

      # Make the nodes read-only
      undef_method :[]=
      members.each do |member|
        undef_method("#{member}=")
      end

      # Override each so it has a Hash-like interface rather than Struct-like.
      # The goal being to mimic a JSON-parsed hash representation of the raw
      def each
        members.map do |key|
          tuple = [key.to_s, self.[](key)]
          yield tuple if block_given?
          tuple
        end
      end

      # Set the renderer to use when rendering this node to HTML.
      # By default a node does not have a renderer, and #to_html will raise an ArgumentError.
      # However if a WCC::Contentful::RichText::Document node is created by the WCC::Contentful::ModelBuilder,
      # it will inject the renderer configured in WCC::Contentful::Services#rich_text_renderer into the node.
      attr_accessor :renderer

      # Render the node to HTML using the configured renderer.
      # See WCC::Contentful::RichTextRenderer for more information.
      def to_html
        unless renderer
          raise ArgumentError,
            'No renderer provided during tokenization.  ' \
            'Please configure the rich_text_renderer in your WCC::Contentful configuration.'
        end

        renderer.call(self)
      end
    end

    class_methods do
      # Default value for node_type covers most cases
      def node_type
        name.demodulize.underscore.dasherize
      end

      def matches?(node_type)
        self.node_type == node_type
      end

      def tokenize(raw, renderer: nil)
        raise ArgumentError, "Expected '#{node_type}', got '#{raw['nodeType']}'" unless matches?(raw['nodeType'])

        values =
          members.map do |symbol|
            val = raw[symbol.to_s]

            case symbol
            when :content
              WCC::Contentful::RichText.tokenize(val, renderer: renderer)
            else
              val
            end
          end

        new(*values).tap do |node|
          next unless renderer

          node.renderer = renderer
        end
      end
    end
  end
end

# frozen_string_literal: true

module WCC::Contentful::RichText
  module Node
    extend ActiveSupport::Concern

    def keys
      members.map(&:to_s)
    end

    included do
      include Enumerable

      undef_method :[]=
      alias_method :node_type, :nodeType

      # Override each so it has a Hash-like interface rather than Struct-like.
      # The goal being to mimic a JSON-parsed hash representation of the raw
      def each
        members.map do |key|
          yield [key, self.[](key)] if block_given?
        end
      end
    end

    class_methods do
      # Default value for node_type covers most cases
      def node_type
        name.demodulize.underscore.dasherize
      end

      def tokenize(raw, _context = nil)
        unless raw['nodeType'] == node_type
          raise ArgumentError, "Expected '#{node_type}', got '#{raw['nodeType']}'"
        end

        values =
          members.map do |symbol|
            val = raw[symbol.to_s]

            case symbol
            when :content
              WCC::Contentful::RichText.tokenize(val)
              # when :data
              # TODO: resolve links...
            else
              val
            end
          end

        new(*values)
      end
    end
  end
end

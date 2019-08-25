# typed: true
# frozen_string_literal: true

module WCC::Contentful
  # The result of running the indexer on raw content types to produce
  # a type definition which can be used to build models or graphql types.
  class IndexedRepresentation
    def initialize(types = {})
      @types = types
    end

    delegate :keys, to: :@types
    delegate :[], to: :@types
    delegate :each_with_object, to: :@types
    delegate :each_value, to: :@types

    def []=(id, value)
      raise ArgumentError unless value.is_a?(ContentType)

      @types[id] = value
    end

    def self.from_json(hash)
      hash = JSON.parse(hash) if hash.is_a?(String)

      ret = IndexedRepresentation.new
      hash.each do |id, content_type_hash|
        ret[id] = ContentType.new(content_type_hash)
      end
      ret
    end

    def to_json(*args)
      @types.to_json(*args)
    end

    def deep_dup
      self.class.new(@types.deep_dup)
    end

    def ==(other)
      my_keys = keys
      return false unless my_keys == other.keys

      my_keys.all? { |k| self[k] == other[k] }
    end

    class ContentType
      ATTRIBUTES = %i[
        name
        content_type
        fields
      ].freeze

      attr_accessor(*ATTRIBUTES)

      def initialize(hash_or_id = nil)
        @fields = {}
        return unless hash_or_id

        if hash_or_id.is_a?(String)
          @name = hash_or_id
          return
        end

        if raw_fields = (hash_or_id.delete('fields') || hash_or_id.delete(:fields))
          raw_fields.each do |field_name, raw_field|
            @fields[field_name] = Field.new(raw_field)
          end
        end

        hash_or_id.each { |k, v| public_send("#{k}=", v) }
      end

      def deep_dup
        dup_hash =
          ATTRIBUTES.each_with_object({}) do |att, h|
            h[att] = public_send(att)
          end
        self.class.new(dup_hash)
      end

      def ==(other)
        ATTRIBUTES.all? { |att| public_send(att) == other.public_send(att) }
      end
    end

    class Field
      ATTRIBUTES = %i[
        name
        type
        array
        required
        link_types
      ].freeze

      attr_accessor(*ATTRIBUTES)

      TYPES = %i[
        String
        Int
        Float
        DateTime
        Boolean
        Json
        Coordinates
        Link
        Asset
      ].freeze

      def type=(raw_type)
        unless TYPES.include?(raw_type)
          raise ArgumentError, "Unknown type #{raw_type}, expected one of: #{TYPES}"
        end

        @type = raw_type
      end

      def initialize(hash_or_id = nil)
        return unless hash_or_id

        if hash_or_id.is_a?(String)
          @name = hash_or_id
          return
        end

        unless hash_or_id.is_a?(Hash)
          ATTRIBUTES.each { |att| public_send("#{att}=", hash_or_id.public_send(att)) }
          return
        end

        if raw_type = hash_or_id.delete('type')
          raw_type = raw_type.to_sym
          unless TYPES.include?(raw_type)
            raise ArgumentError, "Unknown type #{raw_type}, expected one of: #{TYPES}"
          end

          @type = raw_type
        end

        hash_or_id.each { |k, v| public_send("#{k}=", v) }
      end

      def ==(other)
        ATTRIBUTES.all? { |att| public_send(att) == other.public_send(att) }
      end
    end
  end
end

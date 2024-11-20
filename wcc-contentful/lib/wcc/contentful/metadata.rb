# frozen_string_literal: true

WCC::Contentful::Metadata =
  Struct.new(:raw) do
    def tags
      @tags ||=
        Array(raw['tags']).map do |tag|
          WCC::Contentful::Link.new(tag) if tag.is_a?(Hash)
        end
    end
  end

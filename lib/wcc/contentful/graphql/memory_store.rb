# frozen_string_literal: true

require 'singleton'

module WCC::Contentful::Graphql
  class MemoryStore
    include Singleton

    def initialize
      @hash = {}
      @mutex = Mutex.new
    end

    def index(key, value)
      @mutex.synchronize do
        @hash[key] = value
      end
    end

    def find(key)
      @mutex.synchronize do
        @hash[key]
      end
    end

    def find_by(content_type:)
      @hash.each_with_object([]) do |(_k, v), a|
        content_type = v.dig('sys', 'contentType', 'sys', 'id')
        next if content_type.nil?
        a << v
      end
    end
  end
end

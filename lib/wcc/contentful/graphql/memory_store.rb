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
  end
end

# frozen_string_literal: true

gem 'graphql', '~> 1.7'
require 'graphql'

module WCC::Contentful
  # This module builds a GraphQL schema out of our IndexedRepresentation.
  # It is currently unused and not hooked up in the WCC::Contentful.init! method.
  # TODO: https://github.com/watermarkchurch/wcc-contentful/issues/14 hook it up
  module Graphql
  end
end

require_relative 'graphql/builder'
require_relative 'graphql/federation'
require_relative 'ext/services'

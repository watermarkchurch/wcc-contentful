# frozen_string_literal: true

require 'wcc/contentful/middleman/version'

require "middleman-core"
Middleman::Extensions.register :wcc_contentful do
  require "wcc/contentful/middleman/extension"
  MyExtension
end

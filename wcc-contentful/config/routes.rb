# typed: false
# frozen_string_literal: true

WCC::Contentful::Engine.routes.draw do
  post 'webhook/receive', to: 'wcc/contentful/webhook#receive'
end

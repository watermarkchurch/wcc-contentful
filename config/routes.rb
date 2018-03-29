# frozen_string_literal: true

WCC::Contentful::Engine.routes.draw do
  post 'webhook/receive', to: 'webhook#receive'
end

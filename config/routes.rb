# frozen_string_literal: true

WCC::Contentful::Engine.routes.draw do
  resources :webhook do
    post 'receive', on: :collection
  end
end

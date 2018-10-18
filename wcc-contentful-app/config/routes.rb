# frozen_string_literal: true

WCC::Contentful::App::Engine.routes.draw do
  get '/:slug', to: 'pages#show'
end

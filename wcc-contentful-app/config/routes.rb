# frozen_string_literal: true

WCC::Contentful::App::Engine.routes.draw do
  get '/:slug', to: 'pages#show'
  post '/contact_form', to: 'contact_form#create'
end

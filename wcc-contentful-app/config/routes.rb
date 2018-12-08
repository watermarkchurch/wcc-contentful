# frozen_string_literal: true

WCC::Contentful::App::Engine.routes.draw do
  get '/*slug', to: 'wcc/contentful/app/pages#show'
  root 'wcc/contentful/app/pages#index'
  post '/contact_form', to: 'wcc/contentful/app/contact_form#create', as: :contact_form
end

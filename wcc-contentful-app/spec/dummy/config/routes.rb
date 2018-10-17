# frozen_string_literal: true

Rails.application.routes.draw do
  mount WCC::Contentful::App::Engine, at: '/wcc/contentful/app'
end

# frozen_string_literal: true

Rails.application.routes.draw do
  mount WCC::Contentful::Engine, at: '/wcc/contentful'
end

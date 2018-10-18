# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::PagesController, type: :controller do
  routes { WCC::Contentful::App::Engine.routes }

  it 'loads page by slug' do
    page = contentful_stub('page', slug: '/test')

    get :show, params: { slug: 'test' }

    expect(assigns(:page)).to eq(page)
  end
end

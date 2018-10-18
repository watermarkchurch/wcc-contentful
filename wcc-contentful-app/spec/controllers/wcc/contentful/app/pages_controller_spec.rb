# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::PagesController, type: :controller do
  routes { WCC::Contentful::App::Engine.routes }

  it 'loads page by slug' do
    page = contentful_stub('page', slug: '/test')

    get :show, params: { slug: 'test' }

    expect(assigns(:page)).to eq(page)
  end

  it 'raises exception when page not found' do
    expect(WCC::Contentful::Model::Page).to receive(:find_by)
      .and_return(nil)

    expect {
      get :show, params: { slug: 'not-found' }
    }.to raise_error(WCC::Contentful::App::PageNotFoundError)
  end
end

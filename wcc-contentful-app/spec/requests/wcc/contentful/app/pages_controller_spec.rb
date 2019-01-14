# frozen_string_literal: true

require 'rails_helper'

class MyPage < WCC::Contentful::Model::Page
end

RSpec.describe WCC::Contentful::App::PagesController, type: :request do
  it 'loads homepage off of site config' do
    page = contentful_create('page', slug: '/')
    _config = contentful_stub('siteConfig',
      foreign_key: 'default',
      homepage: page)

    get '/'

    expect(response).to render_template('pages/show')
    expect(assigns(:page)).to eq(page)
  end

  it 'loads the "/" page when no site config exists' do
    page = contentful_stub('page', slug: '/')
    expect(WCC::Contentful::Model::SiteConfig).to receive(:find_by)
      .and_return(nil)

    get '/'

    expect(response).to render_template('pages/show')
    expect(assigns(:page)).to eq(page)
  end

  it 'allows overloading the Page model' do
    allow(::WCC::Contentful::Model).to receive(:resolve_constant)
      .with('page')
      .and_return(MyPage)

    page = contentful_stub('page', slug: '/test')

    expect(::MyPage).to receive(:find_by).with(hash_including(slug: '/test'))
      .and_return(page)

    get '/test'
  end

  it 'loads page by slug' do
    page = contentful_stub('page', slug: '/test')

    get '/test'

    expect(assigns(:page)).to eq(page)
  end

  it 'uses redirect when given' do
    expect(MyPage).to receive(:find_by)
      .and_return(nil)
    redirect = contentful_stub('redirect',
      slug: '/test',
      external_link: 'https://www.google.com')

    get '/test'

    expect(response).to redirect_to(redirect.external_link)
  end

  it 'raises exception when page not found' do
    expect(MyPage).to receive(:find_by)
      .and_return(nil)
    expect(WCC::Contentful::Model::Redirect).to receive(:find_by)
      .and_return(nil)

    expect {
      get '/not-found'
    }.to raise_error(WCC::Contentful::App::PageNotFoundError)
  end
end

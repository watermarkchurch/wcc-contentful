# frozen_string_literal: true

require 'rails_helper'

class MyPage < WCC::Contentful::Model::Page
end

RSpec.describe WCC::Contentful::App::PagesController, type: :request do
  before do
    MyPage.register_for_content_type('page')
  end

  it 'loads homepage off of site config' do
    page = contentful_create('page', slug: '/')
    _config = contentful_stub('siteConfig',
      foreign_key: 'default',
      homepage: page)

    get '/'

    expect(response).to render_template('pages/show')
    expect(assigns(:page)).to be_a(page.class)
    expect(assigns(:page).raw).to eq(page.raw)
  end

  it 'loads the "/" page when no site config exists' do
    page = contentful_stub('page', slug: '/')
    expect(WCC::Contentful::Model::SiteConfig).to receive(:find_by)
      .and_return(nil)

    get '/'

    expect(response).to render_template('pages/show')
    expect(assigns(:page)).to be_a(page.class)
    expect(assigns(:page).raw).to eq(page.raw)
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

    expect(assigns(:page)).to be_a(page.class)
    expect(assigns(:page).raw).to eq(page.raw)
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

      get '/not-found'

    # Rails 7.2 behavior
    expect(response).to have_http_status(500)
  rescue WCC::Contentful::App::PageNotFoundError
    # Rails 7.1 and below behavior
    # OK
  end

  it 'uses preview if preview param set' do
    page = contentful_create('page', slug: '/test')

    expect(MyPage).to receive(:find_by)
      .with(slug: '/test', options: { include: 3, preview: true })
      .and_return(page)
    expect(WCC::Contentful::Model::Redirect).to_not receive(:find_by)

    # act
    with_preview_password do |pw|
      get '/test', params: { preview: pw }
    end

    expect(assigns(:page)).to be_a(page.class)
    expect(assigns(:page).raw).to eq(page.raw)
  end

  it 'uses preview in redirect as well' do
    redirect = contentful_create('redirect',
      slug: '/test',
      external_link: 'https://www.google.com')

    expect(MyPage).to receive(:find_by)
      .with(slug: '/test', options: { include: 3, preview: true })
    expect(WCC::Contentful::Model::Redirect).to receive(:find_by)
      .with(slug: '/test', options: { include: 0, preview: true })
      .and_return(redirect)

    # act
    with_preview_password do |pw|
      get '/test', params: { preview: pw }
    end

    expect(response).to redirect_to(redirect.external_link)
  end

  it 'does not use preview when password doesnt match' do
    expect(MyPage).to receive(:find_by)
      .with(slug: '/test', options: { include: 3, preview: false })
    expect(WCC::Contentful::Model::Redirect).to receive(:find_by)
      .with(slug: '/test', options: { include: 0, preview: false })

    with_preview_password do |_pw|
      get '/test', params: { preview: 'some other password' }
    end

    # Rails 7.2 behavior
    expect(response).to have_http_status(500)
  rescue WCC::Contentful::App::PageNotFoundError
    # Rails 7.1 and below behavior
    # OK
  end

  it 'uses application controller defined preview? function' do
    allow_any_instance_of(ApplicationController)
      .to receive(:preview?)
      .and_return(true)

    page = contentful_create('page', slug: '/test')
    expect(MyPage).to receive(:find_by)
      .with(slug: '/test', options: { include: 3, preview: true })
      .and_return(page)

    # act
    get '/test'

    expect(assigns(:page)).to eq(page)
  end

  it 'respects application controller defined preview? function even if preview param set' do
    allow_any_instance_of(ApplicationController)
      .to receive(:preview?)
      .and_return(false)

    expect(MyPage).to receive(:find_by)
      .with(slug: '/test', options: { include: 3, preview: false })
    expect(WCC::Contentful::Model::Redirect).to receive(:find_by)
      .with(slug: '/test', options: { include: 0, preview: false })

    # act
    with_preview_password do |_pw|
      get '/test', params: { preview: 'some other password' }
    end

    # Rails 7.2 behavior
    expect(response).to have_http_status(500)
  rescue WCC::Contentful::App::PageNotFoundError
    # Rails 7.1 and below behavior
    # OK
  end

  def with_preview_password
    allow(WCC::Contentful::App).to receive(:configuration)
      .and_return(double('configuration', preview_password: 'topsecret'))
    yield 'topsecret'
  end
end

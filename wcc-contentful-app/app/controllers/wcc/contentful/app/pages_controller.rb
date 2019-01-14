# frozen_string_literal: true

class WCC::Contentful::App::PagesController < ApplicationController
  helper ::WCC::Contentful::App::SectionHelper

  def index
    @page = global_site_config&.homepage ||
      page_model.find_by(slug: '/', options: { include: 3 })
    render 'pages/show'
  end

  def show
    slug = '/' + params[:slug]
    @page = page_model.find_by(slug: slug, options: { include: 3 })

    return render 'pages/show' if @page

    redirect = redirect_model.find_by(slug: slug, options: { include: 0 })
    raise WCC::Contentful::App::PageNotFoundError, slug unless redirect

    redirect_to redirect.href
  end

  private

  def page_model
    WCC::Contentful::Model.resolve_constant('page')
  end

  def redirect_model
    WCC::Contentful::Model.resolve_constant('redirect')
  end

  def global_site_config
    # They may have not installed `site-config` in the project
    return unless defined?(WCC::Contentful::Model::SiteConfig)

    @global_site_config ||= WCC::Contentful::Model::SiteConfig.instance
  end
end

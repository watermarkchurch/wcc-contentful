# frozen_string_literal: true

class WCC::Contentful::App::PagesController < ApplicationController
  helper SectionHelper

  def index
    @page = global_site_config&.homepage ||
      WCC::Contentful::Model::Page.find_by(slug: '/', options: { include: 3 })
    render 'wcc/contentful/app/pages/show'
  end

  def show
    slug = '/' + params[:slug]
    @page = WCC::Contentful::Model::Page.find_by(slug: slug, options: { include: 3 })
    return if @page

    redirect = WCC::Contentful::Model::Redirect.find_by(slug: slug, options: { include: 0 })
    raise WCC::Contentful::App::PageNotFoundError, slug unless redirect

    redirect_to redirect.href
  end

  private

  def global_site_config
    # They may have not installed `site-config` in the project
    return unless defined?(WCC::Contentful::Model::SiteConfig)

    @global_site_config ||= WCC::Contentful::Model::SiteConfig.instance
  end
end

# frozen_string_literal: true

class WCC::Contentful::App::PagesController < ApplicationController
  include WCC::Contentful::App::PreviewPassword

  helper ::WCC::Contentful::App::SectionHelper

  def index
    @page = global_site_config&.homepage ||
      page_model.find_by(slug: '/', options: { include: 3, preview: preview? })
    render 'pages/show'
  end

  def show
    slug = "/#{params[:slug]}"
    @page = page_model.find_by(slug: slug, options: { include: 3, preview: preview? })

    return render 'pages/show' if @page

    redirect = redirect_model.find_by(slug: slug, options: { include: 0, preview: preview? })
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

  def site_config_model
    # They may have not installed `site-config` in the project
    WCC::Contentful::Model.resolve_constant('site-config')
  rescue WCC::Contentful::ContentTypeNotFoundError
    nil
  end

  def global_site_config
    return unless model = site_config_model

    @global_site_config ||= model.instance(preview?)
  end
end

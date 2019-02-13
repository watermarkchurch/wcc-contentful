# frozen_string_literal: true

class WCC::Contentful::App::PagesController < ApplicationController
  helper ::WCC::Contentful::App::SectionHelper

  def index
    @page = global_site_config&.homepage ||
      page_model.find_by(slug: '/', options: { include: 3, preview: preview? })
    render 'pages/show'
  end

  def show
    slug = '/' + params[:slug]
    @page = page_model.find_by(slug: slug, options: { include: 3, preview: preview? })

    return render 'pages/show' if @page

    redirect = redirect_model.find_by(slug: slug, options: { include: 0, preview: preview? })
    raise WCC::Contentful::App::PageNotFoundError, slug unless redirect

    redirect_to redirect.href
  end

  private

  def preview?
    return super if defined?(super)

    @preview ||=
      if preview_password.present?
        params[:preview]&.chomp == preview_password.chomp
      else
        false
      end
  end

  def preview_password
    WCC::Contentful::App.configuration.preview_password
  end

  def page_model
    WCC::Contentful::Model.resolve_constant('page')
  end

  def redirect_model
    WCC::Contentful::Model.resolve_constant('redirect')
  end

  def global_site_config
    # They may have not installed `site-config` in the project
    return unless defined?(WCC::Contentful::Model::SiteConfig)

    @global_site_config ||= WCC::Contentful::Model::SiteConfig.instance(preview?)
  end
end

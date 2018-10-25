# frozen_string_literal: true

class WCC::Contentful::App::PagesController < ApplicationController
  helper SectionHelper

  def show
    slug = '/' + params[:slug]
    @page = WCC::Contentful::Model::Page.find_by(slug: slug, options: { include: 3 })
    return if @page

    redirect = WCC::Contentful::Model::Redirect.find_by(slug: slug, options: { include: 0 })
    raise WCC::Contentful::App::PageNotFoundError, slug unless redirect

    redirect_to redirect.href
  end
end

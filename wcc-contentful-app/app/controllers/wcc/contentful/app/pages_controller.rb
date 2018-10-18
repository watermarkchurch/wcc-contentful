# frozen_string_literal: true

class WCC::Contentful::App::PagesController < ApplicationController
  helper SectionHelper

  def show
    @page = WCC::Contentful::Model::Page.find_by(slug: '/' + params[:slug], options: { include: 3 })
    raise ::Exceptions::PageNotFoundError, '/' + params[:slug] unless @page
  end
end

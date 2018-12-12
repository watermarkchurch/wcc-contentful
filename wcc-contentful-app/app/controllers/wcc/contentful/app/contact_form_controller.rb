# frozen_string_literal: true

class WCC::Contentful::App::ContactFormController < ApplicationController
  def create
    form_model.send_email(form_params)

    render json: { type: 'success', message: "Thanks for reaching out. We'll be in touch soon!" }
  end

  private

  def form_model
    raise ArgumentError, 'missing form ID' unless params[:id]

    @form_model ||= WCC::Contentful::Model::SectionContactForm.find(params[:id])
  end

  def form_params
    params.slice(*form_model.fields.map(&:title), params[:person_email])
  end
end

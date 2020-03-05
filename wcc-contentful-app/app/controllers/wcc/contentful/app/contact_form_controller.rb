# frozen_string_literal: true

class WCC::Contentful::App::ContactFormController < ApplicationController
  include WCC::Contentful::App::PreviewPassword

  def create
    address =
      form_model.to_address(email_object_id: params[:email_object_id])

    form_model.send_email(
      form_params.merge!(
        {
          notification_email: address,
          internal_title: params[:internal_title]
        }
      )
    )

    render json: { type: 'success', message: "Thanks for reaching out. We'll be in touch soon!" }
  end

  private

  def form_model
    raise ArgumentError, 'missing form ID' unless params[:id]

    @form_model ||= form_class.find(
      params[:id], options: { preview: preview? }
    )
  end

  def form_class
    WCC::Contentful::Model.resolve_constant('section-contact-form')
  end

  def form_params
    params.slice(*form_model.fields.map(&:title))
  end
end

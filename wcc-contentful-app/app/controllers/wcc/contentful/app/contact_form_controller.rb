# frozen_string_literal: true

class WCC::Contentful::App::ContactFormController < ApplicationController
  def create
    address = form_model.to_address(
      opportunity_email: params[:opportunity_email],
      email_object_id: params[:email_object_id]
    )

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

    @form_model ||= WCC::Contentful::Model::SectionContactForm.find(params[:id])
  end

  def form_params
    params.slice(*form_model.fields.map(&:title))
  end
end

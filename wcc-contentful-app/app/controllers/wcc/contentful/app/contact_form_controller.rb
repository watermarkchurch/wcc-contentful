# frozen_string_literal: true

class WCC::Contentful::App::ContactFormController < ApplicationController
  def create
    address = params[:email_object_id] ? email_address(email_model) : form_model.notification_email
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

  def email_address(entry)
    return entry.email if defined?(entry.email)

    raise ArgumentError, 'email is not defined on this entry'
  end

  def email_model
    raise ArgumentError, 'contentful entry does not exist' unless
      entry = WCC::Contentful::Model.find(params[:email_object_id])

    entry
  end

  def form_model
    raise ArgumentError, 'missing form ID' unless params[:id]

    @form_model ||= WCC::Contentful::Model::SectionContactForm.find(params[:id])
  end

  def form_params
    params.slice(*form_model.fields.map(&:title))
  end
end

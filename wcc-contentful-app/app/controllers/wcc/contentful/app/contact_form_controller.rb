# frozen_string_literal: true

class WCC::Contentful::App::ContactFormController < ApplicationController
  def create
    id = params['id']
    raise ArgumentError, 'missing form ID' unless params['id']

    form_model = WCC::Contentful::Model::SectionContactForm.find(id)
    data = params.slice(*form_model.fields.map(&:title))

    WCC::Contentful::Model::SectionContactForm.send_email(
      form_model.notificationEmail,
      data
    )

    render json: { type: 'success', message: "Thanks for reaching out. We'll be in touch soon!" }
  end
end

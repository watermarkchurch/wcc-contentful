# frozen_string_literal: true

class WCC::Contentful::App::ContactFormController < ApplicationController
  def create
    id = params['id']
    raise ArgumentError, 'missing form ID' unless id
    form_model = WCC::Contentful::Model.find(id)
    to_email = form_model.notificationEmail
    data = {}

    form_model.fields.each do |item|
      data[item.title] = params[item.title]
    end

    UserMailer.contact_form_email(to_email, data).deliver_later

    render json: { type: 'success', message: "Thanks for reaching out. We'll be in touch soon!" }
  end
end

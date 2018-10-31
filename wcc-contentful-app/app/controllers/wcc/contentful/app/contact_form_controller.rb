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

    if WCC::Contentful::App.db_connected?
      if ActiveRecord::Base.connection.table_exists? 'wcc_contentful_app_contact_form_submissions'
        WCC::Contentful::App::ContactFormSubmission.create!(
          full_name: data['First and Last Name'],
          email: data['Email'],
          phone_number: data['Phone Number'],
          question: data['Question']
        )
      end
    end

    render json: { type: 'success', message: "Thanks for reaching out. We'll be in touch soon!" }
  end
end

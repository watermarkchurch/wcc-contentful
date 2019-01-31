# frozen_string_literal: true

module WCC::Contentful::App
  class ContactMailer < ::ApplicationMailer
    def contact_form_email(to_email, data)
      @form_data = data

      mail(from: @form_data[:Email], to: to_email, subject: "#{@form_data[:internal_title]} Submission")
    end
  end
end

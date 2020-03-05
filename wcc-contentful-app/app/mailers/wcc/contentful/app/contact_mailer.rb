# frozen_string_literal: true

module WCC::Contentful::App
  class ContactMailer < ::ApplicationMailer
    def contact_form_email(from_email, to_email, data)
      @form_data = data

      from_email ||= 'info@watermark.org'

      mail(from: from_email, to: to_email,
           subject: "#{@form_data[:internal_title]} Submission")
    end
  end
end

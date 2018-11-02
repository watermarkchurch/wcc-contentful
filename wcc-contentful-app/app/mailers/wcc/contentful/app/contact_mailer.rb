# frozen_string_literal: true

module WCC::Contentful::App
  class ContactMailer < ::ApplicationMailer
    def contact_form_email(to_email, data)
      @form_data = data

      mail(to: to_email, subject: 'Contact Us Form Submission')
    end
  end
end

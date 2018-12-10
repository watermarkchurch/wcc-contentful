# frozen_string_literal: true

module WCC::Contentful::App
  if defined?(::ActiveRecord)
    class ContactFormSubmission < ::ActiveRecord::Base
      self.table_name = 'wcc_contentful_app_contact_form_submissions'
    end
  end
end

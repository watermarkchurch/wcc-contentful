# frozen_string_literal: true

module WCC::Contentful::App
  if defined?(::ActiveRecord)
    class ContactFormSubmission < ::ActiveRecord::Base
    end
  end
end

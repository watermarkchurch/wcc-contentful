# frozen_string_literal: true

module WCC::Contentful::App
  class ApplicationMailer < ActionMailer::Base
    default from: 'from@example.com'
    layout 'mailer'
  end
end

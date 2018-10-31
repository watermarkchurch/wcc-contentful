# frozen_string_literal: true

class WCC::Contentful::Model::SectionContactForm < WCC::Contentful::Model
  def send_email(to_email, data)
    UserMailer.contact_form_email(to_email, data).deliver_later

    save_contact_form(data)
  end

  def page
    WCC::Contentful::Model::Page.find_by(sections: { id: id })
  end

  private

  def save_contact_form(data)
    return unless WCC::Contentful::App.db_connected?
    return unless ActiveRecord::Base.connection
      .table_exists? 'wcc_contentful_app_contact_form_submissions'

    WCC::Contentful::App::ContactFormSubmission.create!(
      full_name: data['First and Last Name'],
      email: data['Email'],
      phone_number: data['Phone Number'],
      question: data['Question']
    )
  end
end

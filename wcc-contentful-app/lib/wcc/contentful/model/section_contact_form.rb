# frozen_string_literal: true

class WCC::Contentful::Model::SectionContactForm < WCC::Contentful::Model
  def send_email(data)
    save_contact_form(data)

    ::WCC::Contentful::App::ContactMailer.contact_form_email(data[:notification_email], data).deliver
  end

  def page
    ::WCC::Contentful::Model::Page.find_by(sections: { id: id })
  end

  def to_address(recipient_email: nil, email_object_id: nil)
    return recipient_email if recipient_email.present?
    return email_address(email_model(email_object_id)) if email_object_id.present?

    notification_email
  end

  private

  def email_address(entry)
    return entry.email if defined?(entry.email)

    raise ArgumentError, 'email is not defined on this entry'
  end

  def email_model(email_object_id)
    raise ArgumentError, 'contentful entry does not exist' unless
      entry = ::WCC::Contentful::Model.find(email_object_id)

    entry
  end

  def save_contact_form(data)
    return unless ::WCC::Contentful::App.db_connected?
    return unless ::ActiveRecord::Base.connection
      .table_exists? 'wcc_contentful_app_contact_form_submissions'

    ::WCC::Contentful::App::ContactFormSubmission.create!(form_id: id, data: data)
  end
end

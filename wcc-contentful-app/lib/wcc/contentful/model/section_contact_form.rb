# frozen_string_literal: true

class WCC::Contentful::Model::SectionContactForm < WCC::Contentful::Model
  def send_email(data)
    puts "WHAT DOES THE DATA LOOK LIKE??"
    puts "WHAT DOES THE DATA LOOK LIKE??"
    puts "WHAT DOES THE DATA LOOK LIKE??"
    puts data.inspect
    puts "WHAT DOES THE DATA LOOK LIKE??!!!!"
    puts "WHAT DOES THE DATA LOOK LIKE??!!!!"
    puts "WHAT DOES THE DATA LOOK LIKE??!!!!"
    ::WCC::Contentful::App::ContactMailer.contact_form_email(data[:notification_email], data).deliver

    save_contact_form(data)
  end

  def page
    ::WCC::Contentful::Model::Page.find_by(sections: { id: id })
  end

  private

  def save_contact_form(data)
    return unless ::WCC::Contentful::App.db_connected?
    return unless ::ActiveRecord::Base.connection
      .table_exists? 'wcc_contentful_app_contact_form_submissions'

    ::WCC::Contentful::App::ContactFormSubmission.create!(form_id: id, data: data)
  end
end

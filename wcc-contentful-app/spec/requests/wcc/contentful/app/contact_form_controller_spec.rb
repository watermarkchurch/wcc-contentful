# frozen_string_literal: true

require 'rails_helper'

class MyContactForm < WCC::Contentful::Model::SectionContactForm
end

RSpec.describe WCC::Contentful::App::ContactFormController, type: :request do
  let(:mailer) {
    double(deliver: nil)
  }

  let!(:form) {
    contentful_stub('section-contact-form',
      internal_title: 'Test')
  }

  before do
    allow(::WCC::Contentful::App::ContactMailer).to receive(:contact_form_email)
      .and_return(mailer)

    # Ensure the table wcc_contentful_app_contact_form_submissions exists
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS wcc_contentful_app_contact_form_submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        form_id TEXT,
        data JSON,
        created_at DATETIME,
        updated_at DATETIME
      )
    SQL
  end

  it 'does not allow sending arbitrary email to :recipient_email' do
    expect(::WCC::Contentful::App::ContactMailer).to_not receive(:contact_form_email)
      .with('test@test.com', anything)

    post '/contact_form', params: {
      id: form.id,
      recipient_email: 'test@test.com'
    }
  end

  it 'sends email to person email address' do
    person = double(id: 'TestPerson', email: 'test-person@test.com')
    allow(::WCC::Contentful::Model).to receive(:find)
      .with('TestPerson', anything)
      .and_return(person)

    expect(::WCC::Contentful::App::ContactMailer).to receive(:contact_form_email)
      .with('test-person@test.com', anything)
      .and_return(mailer)
    expect(mailer).to receive(:deliver)

    post '/contact_form', params: {
      id: form.id,
      email_object_id: 'TestPerson'
    }

    expect(response).to have_http_status(:ok)
  end

  context 'section model is extended' do
    before do
      MyContactForm.register_for_content_type('section-contact-form')
    end

    after do
      WCC::Contentful::Model.instance_variable_get('@registry').clear
    end

    it 'resolves to the descendant contact form override' do
      form = contentful_stub('section-contact-form')

      expect(::MyContactForm).to receive(:find)
        .with(form.id, { options: { preview: false } })
        .and_return(form)
      expect(form).to receive(:send_email)

      post '/contact_form', params: { id: form.id }
    end
  end

  context 'preview: true' do
    before do
      expect(WCC::Contentful::Model::SectionContactForm)
        .to_not receive(:find)
        .with(form.id, options: hash_including(preview: false))
    end

    it 'looks up person in preview API' do
      person = double(id: 'TestPerson', email: 'test-person@test.com')
      allow(::WCC::Contentful::Model).to receive(:find)
        .with('TestPerson', options: hash_including(preview: true))
        .and_return(person)

      expect(::WCC::Contentful::App::ContactMailer).to receive(:contact_form_email)
        .with('test-person@test.com', anything)
        .and_return(mailer)
      expect(mailer).to receive(:deliver)

      post '/contact_form', params: {
        id: form.id,
        email_object_id: 'TestPerson',
        preview: WCC::Contentful::App.configuration.preview_password
      }
    end
  end
end

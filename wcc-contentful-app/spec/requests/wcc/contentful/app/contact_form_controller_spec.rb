# frozen_string_literal: true

require 'rails_helper'

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

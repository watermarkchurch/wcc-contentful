# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::Model::SectionContactForm do
  describe '#to_address' do
    let(:section_contact_form) {
      contentful_create(
        'section-contact-form',
        text: '<h2>This should be an H2<\/h2>',
        notification_email: 'basic@email.com'
      )
    }

    Person = Struct.new(:id, :first_name, :last_name, :email)
    let(:person) { Person.new('84', 'test', 'testerson', 'test@test.com') }

    it 'defaults to notification email' do
      expect(section_contact_form.to_address).to eq(section_contact_form.notification_email)
    end

    it 'returns person email if email_object_id provided' do
      allow(WCC::Contentful::Model).to receive(:find).with(person.id)
        .and_return(person)

      expect(
        section_contact_form.to_address(email_object_id: person.id)
      ).to eq(person.email)
    end
  end
end

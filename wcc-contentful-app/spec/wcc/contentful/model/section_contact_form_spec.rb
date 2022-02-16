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

    after do
      # clean out MyContactForm subclass
      WCC::Contentful::Model.instance_variable_get('@registry').clear
    end

    Person = Struct.new(:id, :first_name, :last_name, :email)
    let(:person) { Person.new('84', 'test', 'testerson', 'test@test.com') }

    it 'defaults to notification email' do
      expect(section_contact_form.to_address(email_object_id: nil))
        .to eq(section_contact_form.notification_email)
    end

    it 'returns person email if email_object_id provided' do
      allow(WCC::Contentful::Model).to receive(:find).with(person.id, anything)
        .and_return(person)

      expect(
        section_contact_form.to_address(email_object_id: person.id)
      ).to eq(person.email)
    end

    it 'allows app to override recipient email with its own logic' do
      class MyContactForm < WCC::Contentful::Model::SectionContactForm
        private

        def email_address(entry)
          return entry.contact_email if entry && defined?(entry.contact_email)

          super
        end

        def email_model(email_object_id, **options)
          if email_object_id == 'test'
            return OpenStruct.new(id: 'test', contact_email: 'test-opportunity@test.com')
          end

          super
        end
      end

      my_contact_form = MyContactForm.new(section_contact_form.raw)

      expect(
        my_contact_form.to_address(email_object_id: 'test')
      ).to eq('test-opportunity@test.com')
    end
  end
end

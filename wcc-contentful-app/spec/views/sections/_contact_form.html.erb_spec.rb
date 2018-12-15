# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/contact_form' do
  helper WCC::Contentful::App::SectionHelper

  context 'when partial is rendered from components/section' do
    it 'raises action view template error if text is nil' do
      section = contentful_create('section-contact-form',
        text: nil)

      expect {
        render 'components/section', section: section, email_object_id: 'IDGOESHERE'
      }.to raise_error(ActionView::Template::Error)
    end

    it 'processes the markdown in the section' do
      section = contentful_create('section-contact-form',
        text: '## This should be an H2')

      render 'components/section', section: section, email_object_id: 'IDGOESHERE'

      expect(rendered).to match(/<h2>This should be an H2<\/h2>/)
    end

    it 'does NOT accept email_object_id' do
      email = 'ez.net'
      section = contentful_create('section-contact-form',
        text: '## This should be an H2',
        notification_email: email)

      render 'components/section', section: section, email_object_id: 'IDGOESHERE'

      expect(rendered).to_not have_selector('input#email-object-id', visible: false)
    end
  end

  context 'when partial is rendered directly' do
    it 'accepts and renders email_object_id as a hidden field' do
      email = 'ez.net'
      section = contentful_create('section-contact-form',
        text: '## This should be an H2',
        notification_email: email)

      render 'sections/contact_form', section: section, email_object_id: 'IDGOESHERE'

      expect(rendered).to have_selector('input#email-object-id', visible: false)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/contact_form' do
  helper WCC::Contentful::App::SectionHelper

  it 'raises action view template error if text is nil' do
    section = contentful_create('section-contact-form',
      text: nil)

    expect {
      render 'components/section', section: section
    }.to raise_error(ActionView::Template::Error)
  end

  it 'processes the markdown in the section' do
    section = contentful_create('section-contact-form',
      text: '## This should be an H2')

    render 'components/section', section: section

    expect(rendered).to match(/<h2>This should be an H2<\/h2>/)
  end

  it 'handles person_email' do
    email = 'ez.net'
    not_the_email = 'ez.bucketz'
    section = contentful_create('section-contact-form',
      text: '## This should be an H2')

    render 'components/section', section: section, person_email: email

    expect(rendered).to have_selector("input#person-email[value='#{email}']", visible: false)
    expect(rendered).to_not have_selector(
      "input#person-email[value='#{not_the_email}']",
      visible: false
    )
  end
end

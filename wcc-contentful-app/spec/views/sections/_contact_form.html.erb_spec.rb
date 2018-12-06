# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/contact_form' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders the given section with empty styles' do
    section = contentful_create('section-contact-form')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-contact-form.default')
  end

  it 'processes the markdown in the section' do
    section = contentful_create('section-contact-form',
      text: '## This should be an H2')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to match(/<h2>This should be an H2<\/h2>/)
  end
end

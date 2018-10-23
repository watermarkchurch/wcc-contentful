# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/faq' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders the given section with empty styles' do
    section = contentful_create('section-faq')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-faq.default')
  end

  it 'processes the markdown in the section' do
    section = contentful_create('section-faq',
      faqs: [
        contentful_create('faq', questions: "q1\nq2"),
        contentful_create('faq', answers: '# a1'),
        contentful_create('faq')
      ])

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to match(/<h1>a1<\/h1>/)
  end
end

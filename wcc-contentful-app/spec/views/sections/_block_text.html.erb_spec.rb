# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/block_text' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders the given section with empty styles' do
    section = contentful_create('section-block-text')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-block-text.default')
  end

  it 'processes the markdown in the section' do
    section = contentful_create('section-block-text',
      body: '## This should be an H2')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to match(/<h2>This should be an H2<\/h2>/)
  end
end

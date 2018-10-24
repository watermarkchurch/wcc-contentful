# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/marquee_text' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders successfully' do
    section = contentful_create('section-marquee-text')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-marquee-text.default')
  end

  it 'renders section tag' do
    section = contentful_create('section-marquee-text',
      tag: 'test-tag <div>escaped</div>')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('.section-marquee-text__tag')
    body = Capybara.string(rendered)
    expect(body.find('.section-marquee-text__tag').text)
      .to eq('test-tag <div>escaped</div>')
  end

  it 'renders section body with line breaks' do
    section = contentful_create('section-marquee-text',
      body: 'test&nbsp;body<br/><div>escaped</div>')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('.section-marquee-text__body')
    expect(rendered)
      .to include('test&nbsp;body<br/>&lt;div&gt;escaped&lt;/div&gt;')
  end
end

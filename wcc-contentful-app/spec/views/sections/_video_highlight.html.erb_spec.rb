# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/video_highlight' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders successfully' do
    section = contentful_create('section-video-highlight')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-video-highlight.default')
  end

  it 'renders raw embed code' do
    section = contentful_create('section-video-highlight',
      embed_code: '<video src="youtu.be/asdf">')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to include('<video src="youtu.be/asdf">')
  end

  it 'renders tag' do
    section = contentful_create('section-video-highlight',
      tag: 'Some Video')

    render partial: 'components/section', locals: { section: section }

    body = Capybara.string(rendered.to_s)
    expect(body.find('.section-video-highlight__tag').text.strip).to eq('Some Video')
  end

  it 'renders markdown subtext' do
    section = contentful_create('section-video-highlight',
      subtext: '## expect h2')

    render partial: 'components/section', locals: { section: section }

    body = Capybara.string(rendered.to_s)
    subtext = body.find('.section-video-highlight__subtext')
    expect(subtext.find('h2').text.strip).to eq('expect h2')
  end
end

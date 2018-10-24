# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/video' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders successfully' do
    section = contentful_create('section-video')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-video.default')
  end

  it 'renders raw embed code' do
    section = contentful_create('section-video',
      embed_code: '<video src="youtu.be/asdf">')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to include('<video src="youtu.be/asdf">')
  end

  it 'renders title' do
    section = contentful_create('section-video',
      title: 'Some Video')

    render partial: 'components/section', locals: { section: section }

    body = Capybara.string(rendered)
    expect(body.find('.section-video-content__title').text.strip).to eq('Some Video')
  end
end

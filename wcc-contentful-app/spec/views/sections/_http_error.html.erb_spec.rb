# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/http_error' do
  helper WCC::Contentful::App::SectionHelper
  helper WCC::Contentful::App::MenuHelper

  it 'renders successfully' do
    section = contentful_create('section-http-error')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-http-error.default')
    expect(rendered).to_not have_css('a')
  end

  it 'renders buttons' do
    section = contentful_create('section-http-error',
      action_button: [
        contentful_create('menuButton'),
        nil,
        contentful_create('menuButton')
      ])

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-http-error.default')
    body = Capybara.string(rendered)
    expect(body.all('a').length).to eq(2)
  end
end

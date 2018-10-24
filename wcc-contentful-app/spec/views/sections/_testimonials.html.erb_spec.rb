# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections/testimonials' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders empty' do
    section = contentful_create('section-testimonials')

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to have_css('section.section-testimonials.default')
  end

  it 'renders testimonials' do
    section = contentful_create('section-testimonials',
      testimonials: [
        contentful_create('testimonial'),
        nil,
        contentful_create('testimonial')
      ])

    render partial: 'components/section', locals: { section: section }

    body = Capybara.string(rendered)
    items = body.all('.section-testimonials__item')
    expect(items.length).to eq(2)
  end

  it 'renders photo in both places' do
    image = contentful_image_double
    section = contentful_create('section-testimonials',
      testimonials: [
        contentful_create('testimonial',
          photo: image)
      ])

    render partial: 'components/section', locals: { section: section }

    body = Capybara.string(rendered)
    item = body.find('.section-testimonials__item')
    sidebar = item.find('.section-testimonials__item-sidebar')
    expect(sidebar['style']).to include("background-image: url(#{image.file.url})")

    photo = item.find('.section-testimonials__item-card-meta-photo')
    expect(photo['src']).to eq(image.file.url)
  end

  it 'allows &nbsp and <br/> in quote' do
    section = contentful_create('section-testimonials',
      testimonials: [
        contentful_create('testimonial',
          quote: 'no&nbsp;break<br/>next <a href="#">line</a>')
      ])

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to include('no&nbsp;break<br/>next &lt;a href=&quot;#&quot;&gt;line&lt;/a&gt;')
  end

  it 'renders mini bio markdown' do
    section = contentful_create('section-testimonials',
      testimonials: [
        contentful_create('testimonial',
          mini_bio: '## expect h2')
      ])

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to include('<h2>expect h2</h2>')
  end
end

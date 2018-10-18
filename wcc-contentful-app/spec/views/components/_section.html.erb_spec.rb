# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'components/section' do
  helper WCC::Contentful::App::SectionHelper

  before do
    allow(view).to receive(:render).and_wrap_original do |m, *args|
      if args[0].is_a?(String) && /^sections\/(\S+)/ =~ args[0]
        "<#{args.dig(1, :section).class.name} />".html_safe
      else
        m.call(*args)
      end
    end
  end

  it 'renders the given section with empty styles' do
    faq = contentful_create('section-Faq')

    render partial: 'components/section', locals: { section: faq }

    expect(rendered).to have_css('section.section-faq.default')
  end

  it 'renders the given section with an ID' do
    testimonials = contentful_create('section-Testimonials',
      title: 'Testimonials for Jesus!')

    render partial: 'components/section', locals: { section: testimonials }

    expect(rendered).to have_css('#Testimonials-for-Jesus-')
  end

  it 'renders the section style' do
    faq = contentful_create('section-Faq',
      style: 'light')

    render partial: 'components/section', locals: { section: faq }

    expect(rendered).to have_css('section.section-faq.light')
    expect(rendered).to_not have_css('section.default')
  end

  it 'renders additional styles' do
    faq = contentful_create('section-Faq',
      style: 'light')

    render partial: 'components/section', locals: { section: faq, styles: ['test'] }

    expect(rendered).to have_css('section.section-faq.light.test')
  end

  it 'renders style collection' do
    video_highlight = contentful_create('section-VideoHighlight',
      styles: %w[rounded vertical])

    render partial: 'components/section', locals: { section: video_highlight }

    expect(rendered).to have_css('section.section-videohighlight.rounded.vertical')
  end

  it 'renders when style collection is nil' do
    video_highlight = contentful_create('section-VideoHighlight',
      styles: nil)

    render partial: 'components/section', locals: { section: video_highlight, styles: ['test'] }

    expect(rendered).to have_css('section.section-videohighlight.test')
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'components/section' do
  helper WCC::Contentful::App::SectionHelper

  it 'renders the given section with empty styles' do
    faq = contentful_create('section-Faq')
    stub_template 'sections/_faq.html.erb' => '<FAQ />'

    render partial: 'components/section', locals: { section: faq }

    expect(rendered).to have_css('section.section-faq.default')
  end

  it 'renders the given section with an ID' do
    testimonials = contentful_create('section-Testimonials',
      title: 'Testimonials for Jesus!')
    stub_template 'sections/_testimonials.html.erb' => '<Testimonials />'

    render partial: 'components/section', locals: { section: testimonials }

    expect(rendered).to have_css('#Testimonials-for-Jesus-')
  end

  it 'renders the section style' do
    faq = contentful_create('section-Faq',
      style: 'light')
    stub_template 'sections/_faq.html.erb' => '<FAQ />'

    render partial: 'components/section', locals: { section: faq }

    expect(rendered).to have_css('section.section-faq.light')
    expect(rendered).to_not have_css('section.default')
  end

  it 'renders additional styles' do
    faq = contentful_create('section-Faq',
      style: 'light')
    stub_template 'sections/_faq.html.erb' => '<FAQ />'

    render partial: 'components/section', locals: { section: faq, styles: ['test'] }

    expect(rendered).to have_css('section.section-faq.light.test')
  end

  it 'renders style collection' do
    video_highlight = contentful_create('section-VideoHighlight',
      styles: %w[rounded vertical])
    stub_template 'sections/_videohighlight.html.erb' => '<VideoHighlight />'

    render partial: 'components/section', locals: { section: video_highlight }

    expect(rendered).to have_css('section.section-videohighlight.rounded.vertical')
  end

  it 'renders when style collection is nil' do
    video_highlight = contentful_create('section-VideoHighlight',
      styles: nil)
    stub_template 'sections/_videohighlight.html.erb' => '<VideoHighlight />'

    render partial: 'components/section', locals: { section: video_highlight, styles: ['test'] }

    expect(rendered).to have_css('section.section-videohighlight.test')
  end

  context 'section_prefixes given' do
    it 'renders the section from the section_prefixes directory when exists' do
      faq = contentful_create('section-Faq')

      stub_template 'sections-v2/_faq.html.erb' => '<FAQ-v2 />'

      render partial: 'components/section', locals: {
        section: faq,
        section_prefixes: 'sections-v2'
      }

      expect(rendered).to include('<FAQ-v2 />')
    end

    it "renders from the gem's sections directory when doesn't exist in section_prefixes" do
      faq = contentful_create('section-Faq')

      stub_template 'sections/_faq.html.erb' => '<FAQ-gem />'

      render partial: 'components/section', locals: {
        section: faq,
        section_prefixes: 'sections-v2'
      }

      expect(rendered).to include('<FAQ-gem />')
    end
  end
end

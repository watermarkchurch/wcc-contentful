# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'pages/show' do
  it 'renders empty when no sections present' do
    assign(:page, contentful_create('page', sections: []))

    render template: 'pages/show'

    expect(rendered).to_not have_selector('section')
  end

  it 'renders multiple sections' do
    allow(view).to receive(:render)
      .with({ template: 'pages/show' }, {})
      .and_call_original

    faq = contentful_create('section-Faq')
    expect(view).to receive(:render)
      .with('components/section', { section: faq, index: 0 })

    testimonial = contentful_create('section-Testimonials')
    expect(view).to receive(:render)
      .with('components/section', { section: testimonial, index: 2 })

    assign(:page,
      contentful_create('page',
        sections: [
          faq,
          nil,
          testimonial
        ]))

    render template: 'pages/show'
  end
end

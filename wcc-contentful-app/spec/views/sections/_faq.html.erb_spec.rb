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
        contentful_create('faq', answers: '# a1')
      ])

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to match(/<h1>a1<\/h1>/)
  end

  it 'allows &nbsp and <br/> in questions' do
    section = contentful_create('section-faq',
      faqs: [
        contentful_create('faq', questions: 'no&nbsp;break<br/>next <a href="#">line</a>')
      ])

    render partial: 'components/section', locals: { section: section }

    expect(rendered).to include('no&nbsp;break<br/>next &lt;a href=&quot;#&quot;&gt;line&lt;/a&gt;')
  end

  it 'folds faqs after the number_of_faqs_before_fold' do
    section = contentful_create('section-faq',
      number_of_faqs_before_fold: 2,
      fold_button_hide_text: 'test-hide',
      fold_button_show_text: 'test-show',
      faqs: [
        contentful_create('faq',
          questions: 'q1'),
        contentful_create('faq',
          questions: 'q2'),
        contentful_create('faq',
          questions: 'q3'),
        contentful_create('faq',
          questions: 'q4')
      ])

    render partial: 'components/section', locals: { section: section }

    body = Capybara.string(rendered)
    rows = body.all('.section-faq__row')
    expect(rows.length).to eq(4)

    hidden_rows = body.all('#faq-hidden-collapse .section-faq__row')
    expect(hidden_rows.length).to eq(2)

    expect(body.find('.section-faq__show-more-button__expanded').text.strip).to eq('test-hide')
    expect(body.find('.section-faq__show-more-button__collapsed').text.strip).to eq('test-show')
  end
end

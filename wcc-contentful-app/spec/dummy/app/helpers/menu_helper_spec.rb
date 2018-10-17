# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::MenuHelper, type: :helper do
  before do
    allow(helper).to receive(:current_page?) do |url|
      url = URI(url)
      url.path == URI('/awaken').path &&
        (url.host.blank? || url.host == 'theporch.live')
    end
  end

  describe '#local?' do
    context 'current page is /awaken' do

      {
        '/' => false,
        '/awaken' => false,
        '/awaken#contact' => true,
        '#contact' => true,
        '#' => true,
        '/other-page' => false,
        '/other-page#contact' => false,
      }.each do |(href, result)|
        it "local?('#{href}') should be #{result}" do
          expect(helper.local?(href)).to be result
        end
      end
    end
  end

# TODO: Enable the following tests once we have the contentful test helpers added to this project

  # describe 'render_button' do
  #   let(:result) { result = helper.render_button(button) }

  #   context 'external link' do
  #     subject(:button) {
  #       contentful_factory('menuButton',
  #         externalLink: 'https://other-site.com/awaken'
  #       )
  #     }

  #     it { expect(result).to include 'href="https://other-site.com/awaken"' }
  #     it { expect(result).to include 'target="_blank"' }
  #     it { expect(result).to match /class=\"([^\"]*)external/ }
  #   end

  #   context 'page link' do
  #     subject(:button) {
  #       contentful_factory('menuButton',
  #         link: contentful_factory('page-v2', slug: '/awaken')
  #       )
  #     }

  #     it { expect(result).to include 'href="/awaken"' }
  #     it { expect(result).to_not include 'target="_blank"' }
  #     it { expect(result).to_not match /class=\"([^\"]*)external/ }
  #   end

  #   context 'local link to other page' do
  #     subject(:button) {
  #       contentful_factory('menuButton',
  #         link: contentful_factory('page-v2', slug: '/other-page'),
  #         sectionLink: contentful_factory('section-faq', bookmarkTitle: 'faqs')
  #       )
  #     }

  #     it { expect(result).to include 'href="/other-page#faqs"' }
  #   end

  #   context 'local link to this page' do
  #     subject(:button) {
  #       contentful_factory('menuButton',
  #         link: contentful_factory('page-v2', slug: '/awaken'),
  #         sectionLink: contentful_factory('section-faq', bookmarkTitle: 'faqs')
  #       )
  #     }

  #     it { expect(result).to include 'href="#faqs"' }
  #   end

  #   context 'local link without page' do
  #     subject(:button) {
  #       contentful_factory('menuButton',
  #         link: nil,
  #         sectionLink: contentful_factory('section-faq', bookmarkTitle: 'faqs')
  #       )
  #     }

  #     it { expect(result).to include 'href="#faqs"' }
  #   end
  # end
end
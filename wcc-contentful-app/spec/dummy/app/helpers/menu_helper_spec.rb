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

  describe 'render_button' do
    let(:result) { result = helper.render_button(button) }

    context 'external link' do
      subject(:button) {
        contentful_create('menuButton', externalLink: 'https://other-site.com/awaken')
      }
      before do
        allow(button).to receive(:material_icon).and_return(nil)
        allow(button).to receive(:external?).and_return(true)
        allow(button).to receive(:style).and_return("white-border")
        allow(button).to receive(:href).and_return('https://other-site.com/awaken')
      end

      it { expect(result).to include 'href="https://other-site.com/awaken"' }
      it { expect(result).to include 'target="_blank"' }
      it { expect(result).to match /class=\"([^\"]*)external/ }
    end

    context 'page link' do
      subject(:button) {
        contentful_create('menuButton',
          link: contentful_create('page',
            slug: '/awaken')
        )
      }

      it { expect(result).to include 'href="/awaken"' }
      it { expect(result).to_not include 'target="_blank"' }
      it { expect(result).to_not match /class=\"([^\"]*)external/ }
    end

    context 'local link to other page' do
      subject(:button) {
        contentful_create('menuButton',
          link: contentful_create('page', slug: '/other-page'),
          sectionLink: contentful_create('section-Faq', bookmarkTitle: 'faqs')
        )
      }

      it { expect(result).to include 'href="/other-page#faqs"' }
    end

    context 'local link to this page' do
      subject(:button) {
        contentful_create('menuButton',
          link: contentful_create('page', slug: '/awaken'),
          sectionLink: contentful_create('section-faq', bookmarkTitle: 'faqs')
        )
      }

      it { expect(result).to include 'href="#faqs"' }
    end

    context 'local link without page' do
      subject(:button) {
        contentful_create('menuButton',
          link: nil,
          sectionLink: contentful_create('section-faq', bookmarkTitle: 'faqs')
        )
      }

      it { expect(result).to include 'href="#faqs"' }
    end

    context 'button with icon' do
      subject(:button) { contentful_create('menuButton', icon: contentful_image_double )}

      it { expect(result).to include 'icon-only' }
      it { expect(result).to_not include('text-only') }
    end

    context 'button with material icon' do
      subject(:button) { contentful_create('menuButton', material_icon: 'test' )}

      it { expect(result).to include 'icon-only' }
      it { expect(result).to_not include('text-only') }
    end

    context 'button with text and icon' do
      subject(:button) { contentful_create('menuButton',
        icon: contentful_image_double, text: 'test' ) }

      it { expect(result).to_not include('icon-only') }
      it { expect(result).to_not include('text-only') }

      it 'renders both icon and text' do
        expect(result).to include("src=\"#{button.icon.file.url}\"")
        expect(result).to include("<span>test</span>")
      end
    end

    context 'button with text, icon, and material icon' do
      subject(:button) { contentful_create('menuButton',
        icon: contentful_image_double,
        material_icon: 'search',
        text: 'test' ) }

      it { expect(result).to_not include('icon-only') }
      it { expect(result).to_not include('text-only') }

      it 'renders both icon and text' do
        expect(result).to include("src=\"#{button.icon.file.url}\"")
        expect(result).to include("<span>test</span>")
        expect(result).to include('<i class="material-icons">search</i>')
      end
      
    end

    context 'button with text only' do
      subject(:button) { contentful_create('menuButton', text: 'test')}

      it { expect(result).to_not include('icon-only') }
      it { expect(result).to include('text-only') }

    end

    context 'empty button' do
      subject(:button) { contentful_create('menuButton')}
      
      it { expect(result).to_not include('icon-only') }
      it { expect(result).to_not include('text-only') }
    end
  end
end
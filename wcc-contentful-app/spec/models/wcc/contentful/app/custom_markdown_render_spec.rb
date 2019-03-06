# frozen_string_literal: true

require 'rails_helper'
require 'redcarpet'

RSpec.describe WCC::Contentful::App::CustomMarkdownRender, type: :model do
  describe '#link' do
    let(:link) {
      'https://www.watermarkresources.com'
    }
    let(:title) {
      'Watermark Homepage'
    }
    let(:content) {
      'Watermark Community Church'
    }
    let(:link_class) {
      'button white '
    }
    let(:relative_link) {
      '/some-page'
    }

    it 'does not raise exception if link_attributes is nil' do
      options = {
        filter_html: true,
        hard_wrap: true,
        space_after_headers: true,
        fenced_code_blocks: true
      }

      renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
      expect { renderer.link(link, title, content) }.to_not raise_exception
    end

    it 'overrides with target blank when external link is rendered' do
      options = {
        filter_html: true,
        hard_wrap: true,
        link_attributes: { target: '_top' },
        space_after_headers: true,
        fenced_code_blocks: true
      }

      renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
      expect(renderer.link(link, title, content)).to include('target="_blank"')
    end

    it 'respects relative links even when target blank is preferred' do
      options = {
        filter_html: true,
        hard_wrap: true,
        link_attributes: { target: '_blank' },
        space_after_headers: true,
        fenced_code_blocks: true
      }

      renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
      expect(renderer.link(relative_link, title, content)).to_not include('target="_blank"')
    end

    context 'when link has a class' do
      it 'returns a hyperlink <a> tag with a class' do
        links_with_classes =
          [
            [
              'https://www.watermarkresources.com',
              'Watermark Homepage',
              'Watermark Community Church',
              'button white '
            ]
          ]
        options = {
          filter_html: true,
          hard_wrap: true,
          link_attributes: { target: '_blank' },
          space_after_headers: true,
          fenced_code_blocks: true,
          links_with_classes: links_with_classes
        }

        renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
        expect(renderer.link(link, title, content)).to include("class=\"#{link_class}\"")
      end

      context 'when link_attributes is empty' do
        it 'still adds target blank for absolute links' do
          links_with_classes =
            [
              [
                'https://www.watermarkresources.com',
                'Watermark Homepage',
                'Watermark Community Church',
                'button white '
              ]
            ]
          options = {
            filter_html: true,
            hard_wrap: true,
            link_attributes: {},
            space_after_headers: true,
            fenced_code_blocks: true,
            links_with_classes: links_with_classes
          }

          renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
          expect(renderer.link(link, title, content)).to include('target="_blank"')
        end
      end
    end

    context 'when link does not have a class' do
      it 'returns a hyperlink <a> tag without a class' do
        options = {
          filter_html: true,
          hard_wrap: true,
          link_attributes: { target: '_blank' },
          space_after_headers: true,
          fenced_code_blocks: true,
          links_with_classes: []
        }

        renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
        expect(renderer.link(link, title, content)).to_not include('class=')
      end

      context 'when link_attributes is empty' do
        it 'still adds target blank for absolute links' do
          options = {
            filter_html: true,
            hard_wrap: true,
            link_attributes: {},
            space_after_headers: true,
            fenced_code_blocks: true,
            links_with_classes: []
          }

          renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
          expect(renderer.link(link, title, content)).to include('target="_blank"')
        end
      end
    end
  end

  describe '#use_target_blank?' do
    context 'when given a relative url' do
      it 'returns false' do
        url = '/awaken'
        options = {
          filter_html: true,
          hard_wrap: true,
          link_attributes: { target: '_blank' },
          space_after_headers: true,
          fenced_code_blocks: true,
          links_with_classes: []
        }

        renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
        expect(renderer.use_target_blank?(url)).to be false
      end
    end

    context 'when given a hash location as url' do
      it 'returns false' do
        url = '#awaken'
        options = {
          filter_html: true,
          hard_wrap: true,
          link_attributes: { target: '_blank' },
          space_after_headers: true,
          fenced_code_blocks: true,
          links_with_classes: []
        }

        renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
        expect(renderer.use_target_blank?(url)).to be false
      end
    end

    context 'when given an absolute url' do
      it 'returns true' do
        url = 'https://www.watermarkresources.com'
        options = {
          filter_html: true,
          hard_wrap: true,
          link_attributes: { target: '_blank' },
          space_after_headers: true,
          fenced_code_blocks: true,
          links_with_classes: []
        }

        renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
        expect(renderer.use_target_blank?(url)).to be true
      end
    end

    context 'when given a mailto url' do
      it 'returns false' do
        url = 'mailto:students@watermark.org'
        options = {
          filter_html: true,
          hard_wrap: true,
          link_attributes: { target: '_blank' },
          space_after_headers: true,
          fenced_code_blocks: true,
          links_with_classes: []
        }

        renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
        expect(renderer.use_target_blank?(url)).to be false
      end
    end
  end
end

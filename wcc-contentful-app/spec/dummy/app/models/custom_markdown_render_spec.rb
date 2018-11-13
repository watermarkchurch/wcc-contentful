# frozen_string_literal: true

require "rails_helper"
require 'redcarpet'

RSpec.describe WCC::Contentful::App::CustomMarkdownRender, :type => :model do
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
        expect(renderer.link(link, title, content)).to eq("<a href=\"#{link}\" title=\"#{title}\" class=\"#{link_class}\" target='_blank'>#{content}</a>")
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
        expect(renderer.link(link, title, content)).to eq("<a href=\"#{link}\" title=\"#{title}\" target='_blank'>#{content}</a>")
      end
    end
  end
  describe '#url_target' do
    context 'when given a relative url' do
      it 'returns nil' do
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
        expect(renderer.url_target(url)).to be_nil
      end
    end

    context 'when given an absolute url' do
      it 'returns target=_blank' do
        url = "https://www.watermarkresources.com"
        options = {
          filter_html: true,
          hard_wrap: true,
          link_attributes: { target: '_blank' },
          space_after_headers: true,
          fenced_code_blocks: true,
          links_with_classes: []
        }

        renderer = WCC::Contentful::App::CustomMarkdownRender.new(options)
        expect(renderer.url_target(url)).to eq("target='_blank'")
      end
    end
  end
end
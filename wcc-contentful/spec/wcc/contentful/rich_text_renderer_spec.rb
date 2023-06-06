# frozen_string_literal: true

require 'rails_helper'
require 'wcc/contentful/rich_text_renderer'

RSpec.describe WCC::Contentful::RichTextRenderer, rails: true do
  let(:document) {
    WCC::Contentful::RichText.tokenize({
      'nodeType' => 'document',
      'content' => content
    })
  }

  let(:content) {
    []
  }

  subject { WCC::Contentful::RichTextRenderer.new(document) }

  # default implementation for test is ActionView, but ensure the renderer
  # class can be loaded without it.
  context 'no action view', rails: false do
    it 'requires an implementation' do
      expect {
        WCC::Contentful::RichTextRenderer.new(document)
      }.to raise_error(NotImplementedError)
    end
  end

  describe '#to_html' do
    context 'with a paragraph' do
      let(:content) {
        [
          {
            'nodeType' => 'paragraph',
            'content' => [
              {
                'nodeType' => 'text',
                'value' => 'This year, we concentrated our efforts around four strategic priorities:'
              }
            ]
          }
        ]
      }

      it 'renders a <p> tag' do
        expect(subject.to_html).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <p>
              <span>This year, we concentrated our efforts around four strategic priorities:</span>
            </p>
          </div>
        HTML
      end
    end

    context 'with a heading' do
      let(:content) {
        [
          {
            'nodeType' => 'heading-1',
            'content' => [
              {
                'nodeType' => 'text',
                'value' => 'Dear Watermark Family,'
              }
            ]
          },

          {
            'nodeType' => 'heading-2',
            'content' => [
              {
                'nodeType' => 'text',
                'value' => '2020 was a year like no other.'
              }
            ]
          }
        ]
      }

      it 'renders header tags' do
        expect(subject.to_html).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <h1>
              <span>Dear Watermark Family,</span>
            </h1>
            <h2>
              <span>2020 was a year like no other.</span>
            </h2>
          </div>
        HTML
      end
    end

    context 'with a list' do
      let(:content) {
        [
          {
            'nodeType' => 'unordered-list',
            'content' => [
              {
                'nodeType' => 'list-item',
                'content' => [
                  {
                    'nodeType' => 'paragraph',
                    'content' => [
                      {
                        'nodeType' => 'text',
                        'value' => 'Deepen our theology of God and His church'
                      }
                    ]
                  }
                ]
              },
              {
                'nodeType' => 'list-item',
                'content' => [
                  {
                    'nodeType' => 'paragraph',
                    'content' => [
                      {
                        'nodeType' => 'text',
                        'value' => 'Make a big church feel smaller'
                      }
                    ]
                  }
                ]
              },
              {
                'nodeType' => 'list-item',
                'content' => [
                  {
                    'nodeType' => 'paragraph',
                    'content' => [
                      {
                        'nodeType' => 'text',
                        'value' => 'Strengthen families'
                      }
                    ]
                  }
                ]
              },
              {
                'nodeType' => 'list-item',
                'content' => [
                  {
                    'nodeType' => 'paragraph',
                    'content' => [
                      {
                        'nodeType' => 'text',
                        'value' => 'Love our city'
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      it 'renders a <ul>' do
        expect(subject.to_html).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <ul>
              <li>
                <p>
                  <span>Deepen our theology of God and His church</span>
                </p>
              </li>
              <li>
                <p>
                  <span>Make a big church feel smaller</span>
                </p>
              </li>
              <li>
                <p>
                  <span>Strengthen families</span>
                </p>
              </li>
              <li>
                <p>
                  <span>Love our city</span>
                </p>
              </li>
            </ul>
          </div>
        HTML
      end
    end
  end
end

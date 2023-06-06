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
    context 'with text' do
      let(:content) {
        [
          {
            'nodeType' => 'text',
            'value' => 'Hello, world!'
          }
        ]
      }

      it 'renders without a tag' do
        expect(subject.to_html).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">Hello, world!</div>
        HTML
      end

      [
        %w[bold strong],
        %w[italic em],
        %w[underline u],
        %w[code code],
        %w[superscript sup],
        %w[subscript sub]
      ].each do |(type, tag)|
        it "renders #{type} mark as <#{tag}>" do
          content[0]['value'] = 'This is '
          content << {
            'nodeType' => 'text',
            'value' => type,
            'marks' => [
              {
                'type' => type
              }
            ]
          }

          expect(subject.to_html.strip).to eq <<~HTML.strip
            <div class="contentful-rich-text">This is <#{tag}>#{type}</#{tag}></div>
          HTML
        end
      end

      it 'renders multiple marks' do
        content[0]['value'] = 'This is '
        content << {
          'nodeType' => 'text',
          'value' => 'bold and italic',
          'marks' => [
            {
              'type' => 'bold'
            },
            {
              'type' => 'italic'
            }
          ]
        }

        expect(subject.to_html.strip).to eq <<~HTML.strip
          <div class="contentful-rich-text">This is <em><strong>bold and italic</strong></em></div>
        HTML
      end
    end

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
            <p>This year, we concentrated our efforts around four strategic priorities:</p>
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
            <h1>Dear Watermark Family,</h1>
            <h2>2020 was a year like no other.</h2>
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
                <p>Deepen our theology of God and His church</p>
              </li>
              <li>
                <p>Make a big church feel smaller</p>
              </li>
              <li>
                <p>Strengthen families</p>
              </li>
              <li>
                <p>Love our city</p>
              </li>
            </ul>
          </div>
        HTML
      end
    end

    context 'with a hyperlink' do
      let(:content) {
        [
          {
            'nodeType' => 'paragraph',
            'content' => [
              {
                'nodeType' => 'text',
                'value' => 'This is a '
              },
              {
                'nodeType' => 'hyperlink',
                'data' => {
                  'uri' => '/some-page'
                },
                'content' => [
                  {
                    'nodeType' => 'text',
                    'value' => 'Hyperlink'
                  }
                ]
              }
            ]
          }
        ]
      }

      it 'renders an <a> tag' do
        expect(subject.to_html).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <p>This is a <a href="/some-page">Hyperlink</a></p>
          </div>
        HTML
      end
    end

    context 'with an asset-hyperlink' do
      let(:content) {
        [
          {
            'nodeType' => 'paragraph',
            'content' => [
              {
                'nodeType' => 'text',
                'value' => 'This is a '
              },
              {
                'nodeType' => 'asset-hyperlink',
                'data' => {
                  'target' => {
                    'sys' => {
                      'id' => '6mbnFhDqoOWFFAaE5O1HD9',
                      'type' => 'Link',
                      'linkType' => 'Asset'
                    }
                  }
                },
                'content' => [
                  {
                    'nodeType' => 'text',
                    'value' => 'asset link'
                  }
                ]
              }
            ]
          }
        ]
      }

      it 'renders an <a> tag' do
        store = double('store', find: {
          'sys' => {
            'id' => '6mbnFhDqoOWFFAaE5O1HD9',
            'type' => 'Asset'
          },
          'fields' => {
            'file' => {
              'url' => '//images.ctfassets.net/abc123/asset.jpg'
            }
          }
        })

        allow(subject).to receive(:store).and_return(store)

        expect(subject.to_html).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <p>This is a <a href="//images.ctfassets.net/abc123/asset.jpg" target="_blank">asset link</a></p>
          </div>
        HTML
      end
    end
  end
end

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
  context 'no implementation configured' do
    before do
      allow(WCC::Contentful).to receive(:configuration)
        .and_return(double('config', rich_text_renderer: nil))
    end

    it 'requires an implementation' do
      expect {
        WCC::Contentful::RichTextRenderer.call(document)
      }.to raise_error(WCC::Contentful::RichTextRenderer::AbstractRendererError)
    end
  end

  shared_examples 'rich text renderer' do
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
        expect(subject.call).to match_inline_html_snapshot <<~HTML
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

          expect(subject.call.strip).to eq <<~HTML.strip
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

        expect(subject.call.strip).to eq <<~HTML.strip
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
        expect(subject.call).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <p>This year, we concentrated our efforts around four strategic priorities:</p>
          </div>
        HTML
      end
    end

    context 'with a blockquote' do
      let(:content) {
        [
          {
            'nodeType' => 'blockquote',
            'content' => [
              {
                'nodeType' => 'paragraph',
                'content' => [
                  {
                    'nodeType' => 'text',
                    'value' => "If you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved.\n" # rubocop:disable Layout/LineLength
                  },
                  {
                    'nodeType' => 'text',
                    'value' => 'Romans 10:9',
                    'marks' => [
                      {
                        'type' => 'subscript'
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      it 'renders a <blockquote> tag' do
        expect(subject.call).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <blockquote>
              <p>If you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved.
          <sub>Romans 10:9</sub></p>
            </blockquote>
          </div>
        HTML
      end
    end

    context 'with a horizontal rule' do
      let(:content) {
        [
          {
            'nodeType' => 'hr'
          }
        ]
      }

      it 'renders a <hr> tag' do
        expect(subject.call).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <hr>
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
        expect(subject.call).to match_inline_html_snapshot <<~HTML
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
        expect(subject.call).to match_inline_html_snapshot <<~HTML
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

    context 'with a table' do
      let(:content) {
        [
          {
            'nodeType' => 'table',
            'content' => [
              {
                'nodeType' => 'table-row',
                'content' => [
                  {
                    'nodeType' => 'table-header-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => 'Star Wars Movie'

                          }
                        ]
                      }
                    ]
                  },
                  {
                    'nodeType' => 'table-header-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => 'Rating'

                          }
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                'nodeType' => 'table-row',
                'content' => [
                  {
                    'nodeType' => 'table-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => 'Episode 4'

                          }
                        ]
                      }
                    ]
                  },
                  {
                    'nodeType' => 'table-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => '8'

                          }
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                'nodeType' => 'table-row',
                'content' => [
                  {
                    'nodeType' => 'table-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => 'Episode 5'

                          }
                        ]
                      }
                    ]
                  },
                  {
                    'nodeType' => 'table-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => '10'

                          }
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                'nodeType' => 'table-row',
                'content' => [
                  {
                    'nodeType' => 'table-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => 'Episode 6'

                          }
                        ]
                      }
                    ]
                  },
                  {
                    'nodeType' => 'table-cell',
                    'content' => [
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => '5'

                          }
                        ]
                      },
                      {
                        'nodeType' => 'paragraph',
                        'content' => [
                          {
                            'nodeType' => 'text',
                            'value' => '(because of the ewoks duh)',
                            'marks' => [
                              {
                                'type' => 'subscript'
                              }
                            ]

                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      it 'renders a <table>' do
        expect(subject.call).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <table>
              <tr>
                <th>
                  <p>Star Wars Movie</p>
                </th>
                <th>
                  <p>Rating</p>
                </th>
              </tr>
              <tr>
                <td>
                  <p>Episode 4</p>
                </td>
                <td>
                  <p>8</p>
                </td>
              </tr>
              <tr>
                <td>
                  <p>Episode 5</p>
                </td>
                <td>
                  <p>10</p>
                </td>
              </tr>
              <tr>
                <td>
                  <p>Episode 6</p>
                </td>
                <td>
                  <p>5</p>
                  <p>
                    <sub>(because of the ewoks duh)</sub>
                  </p>
                </td>
              </tr>
            </table>
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
        expect(subject.call).to match_inline_html_snapshot <<~HTML
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

      it 'renders an <a> tag when connected' do
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

        expect(subject.call).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <p>This is a <a href="//images.ctfassets.net/abc123/asset.jpg" target="_blank">asset link</a></p>
          </div>
        HTML
      end
    end

    context 'with an entry-hyperlink' do
      let(:content) {
        [
          {
            'nodeType' => 'paragraph',
            'content' => [
              {
                'nodeType' => 'text',
                'value' => 'This is an '
              },
              {
                'nodeType' => 'entry-hyperlink',
                'data' => {
                  'target' => {
                    'sys' => {
                      'id' => '6mbnFhDqoOWFFAaE5O1HD9',
                      'type' => 'Link',
                      'linkType' => 'Entry'
                    }
                  }
                },
                'content' => [
                  {
                    'nodeType' => 'text',
                    'value' => 'entry link'
                  }
                ]
              }
            ]
          }
        ]
      }

      it 'renders an <a> tag if the model has #href' do
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

        allow(subject).to receive(:model_api).and_return(
          double('model-api', new_from_raw:
            double('page-model', href: '/some-page'))
        )

        expect(subject.call).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <p>This is an <a href="/some-page">entry link</a></p>
          </div>
        HTML
      end
    end

    context 'with an embedded-asset-block' do
      let(:content) {
        [
          {
            'nodeType' => 'embedded-asset-block',
            'data' => {
              'target' => {
                'sys' => {
                  'id' => '6mbnFhDqoOWFFAaE5O1HD9',
                  'type' => 'Link',
                  'linkType' => 'Asset'
                }
              }
            }
          }
        ]
      }

      it 'renders an <img> tag' do
        store = double('store', find: {
          'sys' => {
            'id' => '6mbnFhDqoOWFFAaE5O1HD9',
            'type' => 'Asset'
          },
          'fields' => {
            'title' => 'John Smith, Sr Pastor',
            'file' => {
              'url' => '//images.ctfassets.net/abc123/asset.jpg'
            }
          }
        })

        allow(subject).to receive(:store).and_return(store)

        expect(subject.call).to match_inline_html_snapshot <<~HTML
          <div class="contentful-rich-text">
            <img src="//images.ctfassets.net/abc123/asset.jpg" alt="John Smith, Sr Pastor">
          </div>
        HTML
      end
    end
  end

  context 'with action view', rails: true do
    before do
      require 'wcc/contentful/action_view_rich_text_renderer'
    end

    subject { WCC::Contentful::ActionViewRichTextRenderer.new(document) }

    it_behaves_like 'rich text renderer'
  end

  # TODO: nokogiri implementation?
end

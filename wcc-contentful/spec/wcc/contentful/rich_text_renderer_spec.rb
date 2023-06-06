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
  end
end

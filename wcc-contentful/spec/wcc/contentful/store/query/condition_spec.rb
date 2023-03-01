# frozen_string_literal: true

require 'wcc/contentful/store/query/condition'

RSpec.describe WCC::Contentful::Store::Query::Condition do
  describe '#each_locale_fallback' do
    let(:subject) {
      described_class.new(
        path,
        :eq,
        'foo',
        locale_fallbacks
      )
    }

    let(:path) {
      %w[fields page es-MX fields title es-MX]
    }

    let(:locale_fallbacks) {
      {}
    }

    context 'when no fallbacks' do
      it 'yields the condition itself' do
        expect(subject.each_locale_fallback.to_a).to eq([subject])
      end

      it 'yields to the block' do
        found = []

        # act
        subject.each_locale_fallback { |x| found << x }

        expect(found).to eq([subject])
      end
    end

    context 'when fallbacks' do
      let(:locale_fallbacks) {
        {
          'es-MX' => 'es-US',
          'es-US' => 'en-US'
        }
      }

      it 'yields the fallback conditions' do
        # act
        found = subject.each_locale_fallback.to_a

        # assert
        values = found.map { |c| c.path.join('.') }
        expect(values[0]).to eq('fields.page.es-MX.fields.title.es-MX')
        expect(values[1]).to eq('fields.page.es-MX.fields.title.es-US')
        expect(values[2]).to eq('fields.page.es-MX.fields.title.en-US')

        expect(values[3]).to eq('fields.page.es-US.fields.title.es-MX')
        expect(values[4]).to eq('fields.page.es-US.fields.title.es-US')
        expect(values[5]).to eq('fields.page.es-US.fields.title.en-US')

        expect(values[6]).to eq('fields.page.en-US.fields.title.es-MX')
        expect(values[7]).to eq('fields.page.en-US.fields.title.es-US')
        expect(values[8]).to eq('fields.page.en-US.fields.title.en-US')
      end
    end

    context 'when used on a sys field' do
      let(:path) {
        %w[sys id]
      }

      it 'yields the condition itself' do
        expect(subject.each_locale_fallback.to_a).to eq([subject])
      end
    end

    context 'when used on sys via a link' do
      let(:path) {
        %w[fields page es-MX sys id]
      }

      let(:locale_fallbacks) {
        {
          'es-MX' => 'es-US',
          'es-US' => 'en-US'
        }
      }

      it 'goes through fallbacks for the link' do
        # act
        found = subject.each_locale_fallback.to_a

        # assert
        values = found.map { |c| c.path.join('.') }
        expect(values[0]).to eq('fields.page.es-MX.sys.id')
        expect(values[1]).to eq('fields.page.es-US.sys.id')
        expect(values[2]).to eq('fields.page.en-US.sys.id')
      end
    end
  end
end

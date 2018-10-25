# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::Model::SiteConfig do
  describe '.instance' do
    before do
      WCC::Contentful::Model::SiteConfig.instance_variable_set('@instance', nil)
    end

    it 'looks the instance up by foreign key' do
      stubbed = contentful_stub('site-config', foreign_key: 'default')

      subject = described_class.instance

      expect(subject).to_not be nil
      subject_h = subject.to_h
      stubbed_h = stubbed.to_h
      expect(subject_h['sys']).to_not be nil
      expect(subject_h['fields']).to_not be nil
      expect(subject_h['sys']).to eq(stubbed_h['sys'])
      expect(subject_h['fields']).to eq(stubbed_h['fields'])
    end

    it 'memoizes the instance' do
      stubbed = contentful_create('site-config', foreign_key: 'default')
      expect(WCC::Contentful::Model::SiteConfig).to receive(:find_by)
        .once
        .and_return(stubbed)

      described_class.instance
      described_class.instance
    end
  end
end

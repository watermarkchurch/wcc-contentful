# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::Middleware::Store do
  let(:next_store) { double }
  let(:implementation) {
    Class.new do
      include WCC::Contentful::Middleware::Store
    end
  }

  subject(:instance) { implementation.new(next_store) }

  %i[
    index
    set
    delete
  ].each do |method|
    it "delegates #{method} to backing store" do
      expect(next_store).to receive(method)

      subject.public_send(method)
    end
  end

  context 'has select' do
    let(:implementation) {
      Class.new do
        include WCC::Contentful::Middleware::Store

        def select(entry)
          entry.dig('fields', 'exclude', 'en-US') != true
        end
      end
    }

    describe '#find' do
      it 'returns entry that matches select' do
        entry = {
          'fields' => {
            'exclude' => nil
          }
        }
        expect(next_store).to receive(:find)
          .with('1234')
          .and_return(entry)

        # act
        found = instance.find('1234')

        expect(found).to eq(entry)
      end

      it 'returns nil for entry that doesnt match select' do
        entry = {
          'fields' => {
            'exclude' => { 'en-US' => true }
          }
        }
        expect(next_store).to receive(:find)
          .with('1234')
          .and_return(entry)

        # act
        found = instance.find('1234')

        expect(found).to be nil
      end
    end

    describe '#find_by' do
      it 'returns entry that matches select' do
        entry = {
          'fields' => {
            'exclude' => nil
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: nil)
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test', filter: { 'sys.id' => '1234' })

        expect(found).to eq(entry)
      end

      it 'returns nil for entry that doesnt match select' do
        entry = {
          'fields' => {
            'exclude' => { 'en-US' => true }
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: nil)
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test', filter: { 'sys.id' => '1234' })

        expect(found).to be nil
      end

      it 'resolves as broken link for linked entry that doesnt match select' do
        entry = {
          'fields' => {
            'link' => {
              'en-US' => {
                'sys' => {
                  'id' => '5678',
                  'type' => 'Entry'
                },
                'fields' => {
                  'exclude' => { 'en-US' => true }
                }
              }
            }
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: { include: 1 })
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test',
                                 filter: { 'sys.id' => '1234' },
                                 options: { include: 1 })

        expect(found).to eq({
          'fields' => {
            'link' => {
              'en-US' => {
                'sys' => {
                  'id' => '5678',
                  'type' => 'Link',
                  'linkType' => 'Entry'
                }
              }
            }
          }
        })
      end
    end

    describe '#find_all' do
      it 'returns only entries that matches select' do
        entries = [
          {
            'fields' => {
              'exclude' => nil
            }
          }, {
            'fields' => {
              'exclude' => { 'en-US' => true }
            }
          }, {
            'fields' => {
              'exclude' => { 'en-US' => false }
            }
          }
        ]
        expect(next_store).to receive(:find_all)
          .with(content_type: 'test', filter: { 'test' => 'ok' }, options: nil)
          .and_return(entries)

        # act
        found = instance.find_all(content_type: 'test', filter: { 'test' => 'ok' })

        expect(found).to eq([
                              entries[0],
                              entries[2]
                            ])
      end

      it 'resolves as broken link for linked entry that doesnt match select' do
        entries = [{
          'fields' => {
            'link' => {
              'en-US' => {
                'sys' => {
                  'id' => '5678',
                  'type' => 'Entry'
                },
                'fields' => {
                  'exclude' => { 'en-US' => true }
                }
              }
            }
          }
        }]
        expect(next_store).to receive(:find_all)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: { include: 1 })
          .and_return(entries)

        # act
        found = instance.find_all(content_type: 'test',
                                  filter: { 'sys.id' => '1234' },
                                  options: { include: 1 })

        expect(found).to eq([{
          'fields' => {
            'link' => {
              'en-US' => {
                'sys' => {
                  'id' => '5678',
                  'type' => 'Link',
                  'linkType' => 'Entry'
                }
              }
            }
          }
        }])
      end
    end
  end
end

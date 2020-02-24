# frozen_string_literal: true

RSpec.shared_examples 'supports nested queries' do |feature_set|
  describe 'nested (join) queries' do
    before { skip('nested_queries feature not supported') } if feature_set == false
    before { pending('nested_queries feature to be implemented') } if feature_set&.to_s == 'pending'

    describe '#find_by' do
      before do
        # add a dummy redirect that we ought to pass over
        redirect2 = entry.deep_dup
        redirect2['sys']['id'] = 'wrong_one'
        redirect2['fields'].delete('page')
        subject.set('wrong_one', redirect2)

        [entry, page, asset].each { |d| subject.set(d.dig('sys', 'id'), d) }
      end

      it 'allows filtering by a reference field' do
        # act
        found = subject.find_by(
          content_type: 'redirect',
          filter: {
            page: {
              slug: { eq: 'some-page' }
            }
          }
        )

        # assert
        expect(found).to_not be_nil
        expect(found.dig('sys', 'id')).to eq('1qLdW7i7g4Ycq6i4Cckg44')
        expect(found.dig('sys', 'contentType', 'sys', 'id')).to eq('redirect')
      end

      it 'allows filtering by reference id' do
        # act
        found = subject.find_by(
          content_type: 'redirect',
          filter: { 'page' => { id: '2zKTmej544IakmIqoEu0y8' } }
        )

        # assert
        expect(found).to_not be_nil
        expect(found.dig('sys', 'id')).to eq('1qLdW7i7g4Ycq6i4Cckg44')
      end

      it 'handles explicitly specified sys attr' do
        # act
        found = subject.find_by(
          content_type: 'redirect',
          filter: {
            page: {
              'sys.contentType.sys.id' => 'page'
            }
          }
        )

        # assert
        expect(found).to_not be_nil
        expect(found.dig('sys', 'id')).to eq('1qLdW7i7g4Ycq6i4Cckg44')
      end
    end
  end
end

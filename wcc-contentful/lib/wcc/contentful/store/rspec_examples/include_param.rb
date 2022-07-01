# frozen_string_literal: true

RSpec.shared_examples 'supports include param' do |feature_set|
  describe 'supports options: { include: >0 }' do
    before { skip('include_param feature not supported') } if feature_set == false
    before { pending('include_param feature not yet implemented') } if feature_set&.to_s == 'pending'

    let(:root) do
      {
        'sys' => {
          'id' => 'root',
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'root' } }
        },
        'fields' => {
          'name' => { 'en-US' => 'root' },
          'link' => { 'en-US' => make_link_to('deep1') },
          'links' => {
            'en-US' => [
              make_link_to('shallow3'),
              make_link_to('deep2')
            ]
          }
        }
      }
    end

    def shallow(id = nil) # rubocop:disable Naming/UncommunicativeMethodParamName
      {
        'sys' => {
          'id' => "shallow#{id}",
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'shallow' } }
        },
        'fields' => { 'name' => { 'en-US' => "shallow#{id}" } }
      }
    end

    def deep(id, link = nil) # rubocop:disable Naming/UncommunicativeMethodParamName
      {
        'sys' => {
          'id' => "deep#{id}",
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'deep' } }
        },
        'fields' => {
          'name' => { 'en-US' => "deep#{id}" },
          'subLink' => { 'en-US' => link || make_link_to("shallow#{id}") }
        }
      }
    end

    describe '#find_by' do
      it 'recursively resolves links if include > 0' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'root', filter: { name: 'root' }, options: {
          include: 2
        })

        # assert
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow1')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow2')
      end

      it 'stops resolving links at include depth' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'root', filter: { name: 'root' }, options: {
          include: 1
        })

        # assert
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
      end

      1.upto(5).each do |depth|
        it "does not call into #find in order to resolve include: #{depth}" do
          skip("supported up to #{feature_set}") if feature_set.is_a?(Integer) && feature_set < depth

          items = [root]
          # 1..N
          1.upto(depth).map do |n|
            items << deep(n, make_link_to("deep#{n + 1}"))
          end
          items.each { |d| subject.set(d.dig('sys', 'id'), d) }

          # Expect
          expect(subject).to_not receive(:find)

          # act
          found = subject.find_by(content_type: 'root', filter: { name: 'root' }, options: {
            include: depth
          })

          link = found.dig('fields', 'link', 'en-US')
          1.upto(depth).each do |_n|
            expect(link.dig('sys', 'type')).to eq('Entry')
            link = link.dig('fields', 'subLink', 'en-US')
          end
          expect(link.dig('sys', 'type')).to eq('Link')
        end
      end

      it 'handles recursion' do
        items = [
          deep(0, make_link_to('deep1')),
          deep(1, make_link_to('deep0'))
        ]
        items.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        r0 = subject.find_by(content_type: 'deep', filter: { id: 'deep0' }, options: {
          include: 4
        })

        link = r0.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
      end
    end

    describe '#find_all' do
      it 'recursively resolves links if include > 0' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        result = subject.find_all(content_type: 'root', options: {
          include: 2
        }).to_a

        # assert
        found = result.first
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow1')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow2')
      end

      it 'stops resolving links at include depth' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        result = subject.find_all(content_type: 'root', options: {
          include: 1
        }).to_a

        # assert
        found = result.first
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
      end

      1.upto(5).each do |depth|
        it "does not call into #find in order to resolve include: #{depth}" do
          skip("supported up to #{feature_set}") if feature_set.is_a?(Integer) && feature_set < depth

          # 1..N
          items =
            0.upto(depth).map do |n|
              deep(n, make_link_to("deep#{n + 1}"))
            end
          items.each { |d| subject.set(d.dig('sys', 'id'), d) }

          # Expect
          expect(subject).to_not receive(:find)

          # act
          results = subject.find_all(content_type: 'deep', options: {
            include: depth
          }).to_a

          results.sort_by { |entry| entry.dig('sys', 'id') }.each_with_index do |found, n|
            link = found.dig('fields', 'subLink', 'en-US')
            1.upto(depth - n).each do |_n|
              expect(link.dig('sys', 'type')).to eq('Entry')
              link = link.dig('fields', 'subLink', 'en-US')
            end
            expect(link.dig('sys', 'type')).to eq('Link')
          end
          expect(results.length).to eq(items.length)
        end
      end

      it 'handles recursion' do
        items = [
          deep(0, make_link_to('deep1')),
          deep(1, make_link_to('deep0'))
        ]
        items.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        results = subject.find_all(content_type: 'deep', options: {
          include: 4
        }).to_a

        results = results.sort_by { |entry| entry.dig('sys', 'id') }

        r0 = results[0]
        link = r0.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
      end
    end
  end
end

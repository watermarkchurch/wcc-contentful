# frozen_string_literal: true

# rubocop:disable Style/BlockDelimiters

RSpec.shared_examples 'supports nested queries' do |feature_set|
  describe 'nested (join) queries' do
    before { skip('nested_queries feature not supported') } if feature_set == false
    before { pending('nested_queries feature to be implemented') } if feature_set&.to_s == 'pending'

    let(:team) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "hw5pse7y1ojx"
              }
            },
            "id": "Team-1234",
            "type": "Entry",
            "createdAt": "2018-03-09T23:39:27.737Z",
            "updatedAt": "2018-03-09T23:39:27.737Z",
            "revision": 1,
            "contentType": {
              "sys": {
                "type": "Link",
                "linkType": "ContentType",
                "id": "team"
              }
            }
          },
          "fields": {
            "name": {
              "en-US": "Dallas Cowboys"
            },
            "members": {
              "en-US": [
                {
                  "sys": {
                    "type": "Link",
                    "linkType": "Entry",
                    "id": "Member-1"
                  }
                },
                {
                  "sys": {
                    "type": "Link",
                    "linkType": "Entry",
                    "id": "Member-2"
                  }
                }
              ]
            },
            "owner": {
              "en-US": {
                "sys": {
                  "type": "Link",
                  "linkType": "Entry",
                  "id": "Owner-1"
                }
              }
            }
          }
        }
      JSON
    }

    let(:member1) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "hw5pse7y1ojx"
              }
            },
            "id": "Member-1",
            "type": "Entry",
            "createdAt": "2019-09-16T19:49:57.879Z",
            "updatedAt": "2019-09-16T19:49:57.879Z",
            "revision": 1,
            "contentType": {
              "sys": {
                "type": "Link",
                "linkType": "ContentType",
                "id": "person"
              }
            }
          },
          "fields": {
            "firstName": {
              "en-US": "Ezekiel "
            },
            "lastName": {
              "en-US": "Elliot"
            },
            "position": {
              "en-US": "Running Back"
            },
            "profileImage": {
              "en-US": {
                "sys": {
                  "type": "Link",
                  "linkType": "Asset",
                  "id": "3pWma8spR62aegAWAWacyA"
                }
              }
            }
          }
        }
      JSON
    }

    let(:member2) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "hw5pse7y1ojx"
              }
            },
            "id": "Member-2",
            "type": "Entry",
            "createdAt": "2019-09-16T19:49:57.879Z",
            "updatedAt": "2019-09-16T19:49:57.879Z",
            "revision": 1,
            "contentType": {
              "sys": {
                "type": "Link",
                "linkType": "ContentType",
                "id": "person"
              }
            }
          },
          "fields": {
            "firstName": {
              "en-US": "Dak"
            },
            "lastName": {
              "en-US": "Prescot"
            },
            "position": {
              "en-US": "Quarterback"
            },
            "profileImage": null
          }
        }
      JSON
    }

    let(:owner) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "hw5pse7y1ojx"
              }
            },
            "id": "Owner-1",
            "type": "Entry",
            "createdAt": "2019-09-16T19:49:57.879Z",
            "updatedAt": "2019-09-16T19:49:57.879Z",
            "revision": 1,
            "contentType": {
              "sys": {
                "type": "Link",
                "linkType": "ContentType",
                "id": "person"
              }
            }
          },
          "fields": {
            "firstName": {
              "en-US": "Jerry"
            },
            "lastName": {
              "en-US": "Jones"
            },
            "position": {
              "en-US": "owner"
            }
          }
        }
      JSON
    }

    describe '#find_by' do
      context 'singular reference' do
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

      context 'array reference' do
        before do
          # add a second team
          team2 = team.deep_dup
          team2['sys']['id'] = 'wrong_one'
          team2['fields'].delete('members')
          subject.set('wrong_one', team2)

          [team, member1, member2, owner].each { |d| subject.set(d.dig('sys', 'id'), d) }
        end

        it 'filters by array reference field' do
          # act
          found = subject.find_by(
            content_type: 'team',
            filter: {
              members: {
                firstName: { eq: 'Dak' }
              }
            }
          )

          # assert
          expect(found).to_not be_nil
          expect(found.dig('sys', 'id')).to eq('Team-1234')
        end

        # The PostgresStore uses a 'links' column to do a join expression,
        # this checks errors related to that case.
        it 'does not include a link in another field' do
          # act
          found = subject.find_by(
            content_type: 'team',
            filter: {
              members: {
                lastName: { eq: 'Jones' }
              }
            }
          )

          expect(found).to be_nil

          found2 = subject.find_by(
            content_type: 'team',
            filter: {
              owner: {
                lastName: { eq: 'Jones' }
              }
            }
          )
          expect(found2).to_not be_nil
        end

        it 'filters by array reference ID' do
          # act
          found = subject.find_by(
            content_type: 'team',
            filter: {
              members: { id: 'Member-1' }
            }
          )

          # assert
          expect(found).to_not be_nil
          expect(found.dig('sys', 'id')).to eq('Team-1234')
        end

        it 'handles explicitly specified sys attr' do
          # act
          found = subject.find_by(
            content_type: 'team',
            filter: {
              members: {
                'sys.contentType.sys.id' => 'person'
              }
            }
          )

          # assert
          expect(found).to_not be_nil
          expect(found.dig('sys', 'id')).to eq('Team-1234')
        end
      end
    end
  end
end

# rubocop:enable Style/BlockDelimiters

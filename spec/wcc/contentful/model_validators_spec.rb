

# frozen_string_literal: true

RSpec.describe(WCC::Contentful::ModelValidators) do
  let(:indexed_types) {
    load_indexed_types('contentful/indexed_types_from_content_type_indexer.json')
  }

  context 'validate_type' do
    it 'should allow raw validation' do
      typedef = indexed_types['Homepage']
      subject =
        Class.new(WCC::ContentfulModel) do
          define_singleton_method(:content_type_definition) do
            typedef
          end

          validate_type do
            required(:fields).schema do
              required('mainMenu').schema do
                required(:type).value(eql?: :Link)
              end
            end
          end
        end

      # act
      errors = subject.validate_type!

      # assert
      expect(errors).to be_success
    end

    it 'should error when validation fails' do
      typedef = indexed_types['Faq']

      subject =
        Class.new(WCC::ContentfulModel) do
          define_singleton_method(:content_type_definition) do
            typedef
          end

          validate_type do
            required(:fields).schema do
              required('numFaqs').schema do
                required(:type).value(eql?: 'String')
              end
            end
          end
        end

      # act
      errors = subject.validate_type!

      # assert
      expect(errors).to_not be_success
      expect(errors.errors[:fields]['numFaqs'][:type])
        .to eq(['must be equal to String'])
    end
  end

  context 'validate_field' do
    it 'should validate Symbol as string field'

    it 'should validate Text as string field'

    it 'should validate Integer as int'

    it 'should validate Float as float'

    it 'should validate Date as DateTime'

    it 'should validate Boolean as bool'

    it 'should error when field missing'

    it 'should error when expected string is actually number'

    it 'should error when expected int is actually Float'

    it 'should error when expected float is actually Int'

    it 'should error when expected DateTime is actually Json'

    it 'should error when expected bool is actually String'
  end
end

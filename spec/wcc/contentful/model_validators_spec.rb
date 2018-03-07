

# frozen_string_literal: true

RSpec.describe(WCC::Contentful::ModelValidators) do
  let(:indexed_types) {
    load_indexed_types('contentful/indexed_types_from_content_type_indexer.json')
  }

  def base_class(content_type)
    typedef = indexed_types[content_type]
    Class.new(WCC::ContentfulModel) do
      define_singleton_method(:content_type_definition) do
        typedef
      end

      define_singleton_method(:content_type) do
        typedef[:content_type]
      end
    end
  end

  def run_validation(my_class)
    schema =
      Dry::Validation.Schema do
        required(my_class.content_type).schema(my_class.schema)
      end

    schema.call(indexed_types)
  end

  context 'validate_type' do
    it 'should allow raw validation' do
      my_class =
        Class.new(base_class('homepage')) do
          validate_type do
            required(:fields).schema do
              required('mainMenu').schema do
                required(:type).value(eql?: :Link)
              end
            end
          end
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should error when validation fails' do
      my_class =
        Class.new(base_class('faq')) do
          validate_type do
            required(:fields).schema do
              required('numFaqs').schema do
                required(:type).value(eql?: 'String')
              end
              required('blah').filled
            end
          end
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors['faq'][:fields]['numFaqs'][:type])
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

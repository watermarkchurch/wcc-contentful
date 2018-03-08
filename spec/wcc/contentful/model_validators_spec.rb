

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

  context 'validate_fields' do
    it 'should allow raw validation' do
      my_class =
        Class.new(base_class('homepage')) do
          validate_fields do
            required('mainMenu').schema do
              required(:type).value(eql?: :Link)
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
          validate_fields do
            required('numFaqs').schema do
              required(:type).value(eql?: :String)
            end
            required('blah').filled
          end
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors['faq'][:fields]['numFaqs'][:type])
        .to eq(['must be equal to String'])
    end

    it 'should run multiple validations in sequence' do
      my_class =
        Class.new(base_class('faq')) do
          validate_fields do
            required('numFaqs').schema do
              required(:type).value(eql?: :Float)
            end
          end

          validate_fields do
            required('answer').schema do
              required(:type).value(eql?: :Boolean)
            end
          end
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors['faq'][:fields]['numFaqs'][:type])
        .to eq(['must be equal to Float'])
      expect(result.errors['faq'][:fields]['answer'][:type])
        .to eq(['must be equal to Boolean'])
    end

    it 'overwrites earlier validations of a field' do
      my_class =
        Class.new(base_class('faq')) do
          validate_fields do
            required('numFaqs').schema do
              required(:type).value(eql?: :Float)
            end
          end

          validate_fields do
            required('numFaqs').schema do
              required(:type).value(eql?: :Int)
            end
          end
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end
  end

  context 'validate_field' do
    it 'should validate Symbol as string field' do
      my_class =
        Class.new(base_class('page')) do
          validate_field :title, :String, :required
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should validate Text as string field'

    it 'should validate Integer as int'

    it 'should validate Float as float'

    it 'should validate Date as DateTime'

    it 'should validate Boolean as bool'

    it 'should error when field missing' do
      my_class =
        Class.new(base_class('page')) do
          validate_field :foo, :String
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('page', :fields, 'foo')).to eq(
        ['is missing']
      )
    end

    it 'should error when expected string is actually number' do
      my_class =
        Class.new(base_class('faq')) do
          validate_field :num_faqs_float, :String
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('faq', :fields, 'numFaqsFloat', :type)).to eq(
        ['must be equal to String']
      )
    end

    it 'should error when expected int is actually Float'

    it 'should error when expected float is actually Int'

    it 'should error when expected DateTime is actually Json'

    it 'should error when expected bool is actually String'
  end
end

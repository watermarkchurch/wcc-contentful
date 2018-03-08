

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

    it 'should validate Text as string field' do
      my_class =
        Class.new(base_class('homepage')) do
          validate_field :hero_text, :String, :optional
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should validate Integer as int' do
      my_class =
        Class.new(base_class('faq')) do
          validate_field :num_faqs, :Int
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should validate Float as float' do
      my_class =
        Class.new(base_class('faq')) do
          validate_field :num_faqs_float, :Float
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should validate Date as DateTime' do
      my_class =
        Class.new(base_class('migrationHistory')) do
          validate_field :started, :DateTime
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should validate Boolean as bool' do
      my_class =
        Class.new(base_class('faq')) do
          validate_field :truthy_or_falsy, :Boolean
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

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

    it 'should error when field is not of expected type' do
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

    it 'should validate array of simple values' do
      my_class =
        Class.new(base_class('ministry')) do
          validate_field :categories, :String, :array
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should fail when expected array is not an array' do
      my_class =
        Class.new(base_class('ministry')) do
          validate_field :name, :String, :array
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('ministry', :fields, 'name', :array)).to_not be_empty
    end

    it 'should fail when array item is not of expected type' do
      my_class =
        Class.new(base_class('ministry')) do
          validate_field :categories, :Int, :array
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('ministry', :fields, 'categories', :type)).to eq(
        ['must be equal to Int']
      )
    end

    it 'should validate single link' do
      my_class =
        Class.new(base_class('section-CardSearch')) do
          validate_field :theme, :Link
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should fail when expected link is not a link' do
      my_class =
        Class.new(base_class('section-CardSearch')) do
          validate_field :name, :Link
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('section-CardSearch', :fields, 'name', :type)).to_not be_empty
    end

    it 'should validate single link with expected content type' do
      my_class =
        Class.new(base_class('redirect2')) do
          validate_field :page_reference, :Link, link_to: 'page'
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should fail when link is not of expected content type' do
      my_class =
        Class.new(base_class('redirect2')) do
          validate_field :page_reference, :Link, link_to: 'foo'
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('redirect2', :fields, 'pageReference', :link_types)).to_not be_empty
    end

    it 'should validate links to one of multiple content types' do
      my_class =
        Class.new(base_class('menu')) do
          validate_field :first_group, :Link, :array, link_to: %w[menu menuItem]
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should fail when link can link to additional unspecified content types' do
      my_class =
        Class.new(base_class('menu')) do
          validate_field :first_group, :Link, :array, link_to: 'menuItem'
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('menu', :fields, 'firstGroup', :link_types)).to_not be_empty
    end

    it 'should validate links to content type by regexp' do
      my_class =
        Class.new(base_class('page')) do
          validate_field :sections, :Link, :array, link_to: /^section/
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to be_success
    end

    it 'should fail when linked content types do not match regexp' do
      my_class =
        Class.new(base_class('page')) do
          validate_field :sections, :Link, :array, link_to: /^section\-F/
        end

      # act
      result = run_validation(my_class)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('page', :fields, 'sections', :link_types)).to_not be_empty
    end
  end
end

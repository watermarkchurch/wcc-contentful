# frozen_string_literal: true

RSpec.describe(WCC::Contentful::App::ModelValidators) do
  let(:content_types) {
    JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
  }

  let(:transformed) {
    described_class.transform_content_types_for_validation(content_types)
  }

  def base_class(content_type)
    Class.new(WCC::Contentful::Model) do
      define_singleton_method(:content_type) do
        content_type
      end
    end
  end

  before do
    WCC::Contentful::Model.validations.clear
  end

  after do
    Object.send(:remove_const, :MyClass) if defined?(MyClass)
    WCC::Contentful::Model.validations.clear
  end

  context 'validate_fields' do
    it 'should allow raw validation' do
      _my_class =
        Class.new(base_class('homepage')) do
          validate_fields do
            required('mainMenu').schema do
              required('type').value(eql?: 'Link')
            end
          end
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should error when validation fails' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_fields do
            required('numFaqs').schema do
              required('type').value(eql?: 'Symbol')
            end
            required('blah').filled
          end
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors['fake-faq']['fields']['numFaqs']['type'])
        .to eq(['must be equal to Symbol'])
    end

    it 'should run multiple validations in sequence' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_fields do
            required('numFaqs').schema do
              required('type').value(eql?: 'Number')
            end
          end

          validate_fields do
            required('answer').schema do
              required('type').value(eql?: 'Boolean')
            end
          end
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('fake-faq', 'fields', 'numFaqs', 'type'))
        .to eq(['must be equal to Number'])
      expect(result.errors.dig('fake-faq', 'fields', 'answer', 'type'))
        .to eq(['must be equal to Boolean'])
    end

    it 'overwrites earlier validations of a field' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_fields do
            required('numFaqs').schema do
              required('type').value(eql?: 'Number')
            end
          end

          validate_fields do
            required('numFaqs').schema do
              required('type').value(eql?: 'Integer')
            end
          end
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end
  end

  context 'validate_field' do
    it 'should validate Symbol as string field' do
      _my_class =
        Class.new(base_class('page')) do
          validate_field :title, :String, :required
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should validate Text as string field' do
      _my_class =
        Class.new(base_class('homepage')) do
          validate_field :hero_text, :String, :optional
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should validate Integer as int' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_field :num_faqs, :Int
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should validate Float as float' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_field :num_faqs_float, :Float
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should validate Date as DateTime' do
      _my_class =
        Class.new(base_class('migrationHistory')) do
          validate_field :started, :DateTime
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should validate Boolean as bool' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_field :truthy_or_falsy, :Boolean
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should error when field missing' do
      _my_class =
        Class.new(base_class('page')) do
          validate_field :foo, :String
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('page', 'fields', 'foo')).to eq(
        ['is missing']
      )
    end

    it 'should error when field is not of expected type' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_field :num_faqs_float, :String
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('fake-faq', 'fields', 'numFaqsFloat', 'type')).to eq(
        ['must be one of: Symbol, Text']
      )
    end

    it 'should validate array of simple values' do
      _my_class =
        Class.new(base_class('ministry')) do
          validate_field :categories, :Array, items: :String
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should fail when expected array is not an array' do
      _my_class =
        Class.new(base_class('ministry')) do
          validate_field :name, :Array, items: :String
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('ministry', 'fields', 'name', 'type')).to eq(
        ['must be equal to Array']
      )
    end

    it 'should fail when array item is not of expected type' do
      _my_class =
        Class.new(base_class('ministry')) do
          validate_field :categories, :Array, items: :Int
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('ministry', 'fields', 'categories', 'items', 'type')).to eq(
        ['must be equal to Integer']
      )
    end

    it 'should validate single link' do
      _my_class =
        Class.new(base_class('section-CardSearch')) do
          validate_field :theme, :Link
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should fail when expected link is not a link' do
      _my_class =
        Class.new(base_class('section-CardSearch')) do
          validate_field :name, :Link
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('section-CardSearch', 'fields', 'name', 'type')).to_not be_empty
    end

    it 'should validate single link with expected content type' do
      _my_class =
        Class.new(base_class('redirect2')) do
          validate_field :page_reference, :Link, link_to: 'page'
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should fail when link is not of expected content type' do
      _my_class =
        Class.new(base_class('redirect2')) do
          validate_field :page_reference, :Link, link_to: 'foo'
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('redirect2', 'fields', 'pageReference',
        'validations', 0, 'linkContentType')).to_not be_empty
    end

    it 'should validate links to one of multiple content types' do
      _my_class =
        Class.new(base_class('menu')) do
          validate_field :items, :Array, link_to: %w[dropdownMenu menuButton]
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should fail when link can link to additional unspecified content types' do
      _my_class =
        Class.new(base_class('menu')) do
          validate_field :items, :Array, link_to: 'menuButton'
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('menu', 'fields', 'items', 'items',
        'validations', 0, 'linkContentType')).to_not be_empty
    end

    it 'should validate links to content type by regexp' do
      _my_class =
        Class.new(base_class('page')) do
          validate_field :sections, :Array, link_to: /^section/
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should fail when linked content types do not match regexp' do
      _my_class =
        Class.new(base_class('page')) do
          validate_field :sections, :Array, link_to: /^section\-F/
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('page', 'fields', 'sections', 'items',
        'validations', 0, 'linkContentType')).to_not be_empty
    end

    it 'should validate links to assets' do
      _my_class =
        Class.new(base_class('homepage')) do
          validate_field :favicons, :Array, items: :Asset
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'should fail when expected asset is not an asset' do
      _my_class =
        Class.new(base_class('homepage')) do
          validate_field :sections, :Array, items: :Asset
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('homepage', 'fields', 'sections', 'items', 'linkType')).to eq(
        ['must be equal to Asset']
      )
    end
  end

  context 'when schema is from CDN not management API' do
    let(:content_types) {
      JSON.parse(load_fixture('contentful/content_types_cdn.json'))
    }

    it 'does not fail for single element link type validation because we dont have the info' do
      _my_class =
        Class.new(base_class('menuButton')) do
          validate_field :link, :Link, :optional, link_to: 'wakka wakka'
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end

    it 'fails for mismatched array link content type because we have that info' do
      _my_class =
        Class.new(base_class('section-Testimonials')) do
          validate_field :testimonials, :Array, link_to: 'asdf'
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors.dig('section-Testimonials', 'fields', 'testimonials'))
        .to_not be_empty
    end
  end

  context 'multiple model validations' do
    it 'validation failures' do
      _my_class =
        Class.new(base_class('fake-faq')) do
          validate_field :num_faqs, :Json
        end
      _my_class2 =
        Class.new(base_class('page')) do
          validate_field :title, :Boolean, :required
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result.errors).to eq({
        'fake-faq' => { 'fields' => { 'numFaqs' => { 'type' => ['must be equal to Json'] } } },
        'page' => { 'fields' => { 'title' => { 'type' => ['must be equal to Boolean'] } } }
      })
    end

    it 'validation success' do
      _my_class =
        Class.new(base_class('homepage')) do
          validate_fields do
            required('mainMenu').schema do
              required('type').value(eql?: 'Link')
            end
          end
        end
      _my_class2 =
        Class.new(base_class('page')) do
          validate_field :title, :String, :required
        end

      # act

      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to be_success
    end
  end

  context 'model subclasses' do
    it 'can add extra failing validations' do
      generated_model_class =
        Class.new(base_class('page')) do
          validate_field :title, :String, :required
        end

      _my_class =
        Class.new(generated_model_class) do
          validate_field :slug, :Number
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)
      result2 = generated_model_class.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result2).to_not be_success
    end

    it 'can add extra passing validations' do
      generated_model_class =
        Class.new(base_class('page')) do
          validate_field :title, :String, :required
        end

      _my_class =
        Class.new(generated_model_class) do
          validate_field :slug, :String
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)
      result2 = generated_model_class.schema.call(transformed)

      # assert
      expect(result).to be_success
      expect(result2).to be_success
    end

    it 'can add extra validations that dont override base validations' do
      generated_model_class =
        Class.new(base_class('page')) do
          validate_field :title, :Json, :required
        end

      _my_class =
        Class.new(generated_model_class) do
          validate_field :slug, :String
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)
      result2 = generated_model_class.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result2).to_not be_success
    end

    it 'can override good base class validations' do
      generated_model_class =
        Class.new(base_class('page')) do
          validate_field :title, :String, :required
        end

      _my_class =
        Class.new(generated_model_class) do
          validate_field :title, :Json
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)
      result2 = generated_model_class.schema.call(transformed)

      # assert
      expect(result).to_not be_success
      expect(result2).to_not be_success
    end

    it 'can override failing base class validations' do
      generated_model_class =
        Class.new(base_class('page')) do
          validate_field :title, :Boolean, :required
        end

      _my_class =
        Class.new(generated_model_class) do
          validate_field :title, :String
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)
      result2 = generated_model_class.schema.call(transformed)

      # assert
      expect(result).to be_success
      expect(result2).to be_success
    end

    it 'can run even when content type singleton method is missing' do
      class MyClass < WCC::Contentful::Model
        validate_field :title, :String
      end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)

      # assert
      expect(result).to_not be_succes
      expect(result.errors).to eq({
        'myClass' => ['is missing']
      })
    end

    it 'can nullify validations on parent' do
      generated_model_class =
        Class.new(base_class('page')) do
          validate_field :asdfblah, :String, :required
        end

      _my_class =
        Class.new(generated_model_class) do
          no_validate_field :asdfblah
        end

      # act
      result = WCC::Contentful::Model.schema.call(transformed)
      result2 = generated_model_class.schema.call(transformed)

      # assert
      expect(result).to be_success
      expect(result2).to be_success
    end
  end
end

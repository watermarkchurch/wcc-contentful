# frozen_string_literal: true

require_relative './operators/in'

(WCC::Contentful::Store::Query::Interface::OPERATORS -
  %i[in]).each do |op|
    RSpec.shared_examples "supports :#{op} operator" do
      it 'TODO'
    end
  end

RSpec.shared_examples 'operators' do |feature_set|
  supported_operators =
    if feature_set.nil?
      WCC::Contentful::Store::Query::Interface::OPERATORS
        .each_with_object({}) { |k, h| h[k] = 'pending' }
    elsif feature_set.is_a?(Array)
      WCC::Contentful::Store::Query::Interface::OPERATORS
        .each_with_object({}) { |k, h| h[k] = feature_set.include?(k.to_sym) }
    elsif feature_s.is_a?(Hash)
      feature_set
    else
      raise ArgumentError, 'Please provide a hash or array of operators to test'
    end

  supported_operators.each do |op, value|
    next if value

    it "does not support :#{op}" do
      expect {
        subject.find_all(content_type: 'test')
          .apply('name' => { op => 'test' })
          .to_a
      }.to raise_error do |ex|
        expect(ex.to_s).to match(/not supported/)
      end
    end
  end

  supported_operators.each do |op, value|
    next unless value

    it_behaves_like "supports :#{op} operator" do
      before { pending(":#{op} operator to be implemented") } if value == 'pending'
    end
  end
end

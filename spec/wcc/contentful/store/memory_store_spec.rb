# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::MemoryStore do
  subject { WCC::Contentful::Store::MemoryStore.new }

  it_behaves_like 'contentful store'
end

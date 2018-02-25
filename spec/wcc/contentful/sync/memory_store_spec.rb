# frozen_string_literal: true

RSpec.describe WCC::Contentful::Sync::MemoryStore do
  subject { WCC::Contentful::Sync::MemoryStore.new }

  it_behaves_like 'contentful store'
end

# frozen_string_literal: true

require_relative './rspec_examples/basic_store'
require_relative './rspec_examples/operators'
require_relative './rspec_examples/nested_queries'
require_relative './rspec_examples/include_param'
require_relative './rspec_examples/locale_queries'

# rubocop:disable Style/BlockDelimiters

# These shared examples are included to help you implement a new store from scratch.
# To get started implementing your store, require this file and then include the
# shared examples in your RSpec block.
#
# The shared examples take a hash which describes the feature set that this store
# implements.  All the additional features start out in the 'pending' state,
# once you've implemented that feature in your store then you can switch them
# to `true`.
#
# [:nested_queries] - This feature allows queries that reference a field on a
#    linked object, example: `Player.find_by(team: { slug: '/dallas-cowboys' })`.
#    This becomes essentially a JOIN.  For reference see the Postgres store.
# [:include_param] - This feature defines how the store respects the `include: n`
#    key in the Options hash.  Some stores can make use of this parameter to get
#    all linked entries of an object in a single query.
#    If your store does not respect the include parameter, then the Model layer
#    will be calling #find a lot in order to resolve linked entries.
# [:locale_queries] - This feature defines how the store respects the `locale: x`
#    key in the Options hash.  If this option is set, then the store needs to
#    compare the query to the appropriate localized value.
#    If the store does not support this, then either the application should not
#    use multiple locales OR should always query using the default locale.
#
# @example
#   require 'wcc/contentful/store/rspec_examples'
#   RSpec.describe MyStore do
#     subject { MyStore.new }
#
#     it_behaves_like 'contentful store', {
#       # nested_queries: true,
#       # include_param: true
#     }
#
RSpec.shared_examples 'contentful store' do |feature_set|
  feature_set = {
    nested_queries: 'pending',
    include_param: 'pending',
    locale_queries: 'pending'
  }.merge(feature_set&.symbolize_keys || {})

  let(:configuration) {
    WCC::Contentful::Configuration.new
  }

  include_examples 'basic store'
  include_examples 'operators', feature_set[:operators]
  include_examples 'supports nested queries', feature_set[:nested_queries]
  include_examples 'supports include param', feature_set[:include_param]
  include_examples 'supports locales in queries', feature_set[:locale_queries]
end

# rubocop:enable Style/BlockDelimiters


# frozen_string_literal: true

##
# This module is included by all models and defines instance
# methods that are not dynamically generated.
module WCC::Contentful::ModelMethods
  def to_json(depth = 0, _context = nil)
    return @raw.deep_dup if depth <= 0
  end
end

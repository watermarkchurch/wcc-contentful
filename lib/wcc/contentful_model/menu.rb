# frozen_string_literal: true

class WCC::ContentfulModel::Menu < WCC::ContentfulModel
  validate_type do
    required(:fields).schema do
      required('name').schema do
        required(:type).value(eql?: :String)
      end

      optional('icon').schema do
        required(:type).value(eql?: :Asset)
      end
    end
  end
end

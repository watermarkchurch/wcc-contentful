# frozen_string_literal: true

class CreateWCCContentfulAppContactFormSubmissions < ActiveRecord::Migration[5.2]
  def change
    create_table :wcc_contentful_app_contact_form_submissions do |t|
      t.string :form_id
      t.json :data, default: {}

      t.timestamps
    end
  end
end

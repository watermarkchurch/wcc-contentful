# frozen_string_literal: true

class CreateWCCContentfulAppContactFormSubmissions < ActiveRecord::Migration[5.2]
  def change
    create_table :wcc_contentful_app_contact_form_submissions do |t|
      t.json :data

      t.timestamps
    end
  end
end

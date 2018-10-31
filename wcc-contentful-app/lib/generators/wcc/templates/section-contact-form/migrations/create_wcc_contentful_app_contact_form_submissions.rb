# frozen_string_literal: true

class CreateWCCContentfulAppContactFormSubmissions < ActiveRecord::Migration[5.2]
  def change
    create_table :wcc_contentful_app_contact_form_submissions do |t|
      t.string :full_name
      t.string :email
      t.string :phone_number
      t.text :question

      t.timestamps
    end
  end
end

# frozen_string_literal: true

class CreatePantheons < ActiveRecord::Migration[8.1]
  def change
    create_table :pantheons do |t|
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :pantheons, "LOWER(name)", unique: true, name: "index_pantheons_on_lower_name"
  end
end

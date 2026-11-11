# frozen_string_literal: true

class CreateGods < ActiveRecord::Migration[8.1]
  def change
    create_table :gods do |t|
      t.references :pantheon, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, null: false, default: []

      t.timestamps
    end

    add_index :gods, "pantheon_id, LOWER(name)", unique: true, name: "index_gods_on_pantheon_id_and_lower_name"
  end
end

# frozen_string_literal: true

class CreateMyths < ActiveRecord::Migration[8.1]
  def change
    create_table :myths do |t|
      t.references :god, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :themes, null: false, default: {}

      t.timestamps
    end
  end
end

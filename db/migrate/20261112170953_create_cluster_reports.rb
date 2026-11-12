# frozen_string_literal: true

class CreateClusterReports < ActiveRecord::Migration[8.1]
  def change
    create_table :cluster_reports do |t|
      t.references :cluster_snapshot, null: false, foreign_key: { on_delete: :cascade }
      t.references :chat, null: true, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.text :prompt, null: false
      t.string :status, null: false, default: "pending"
      t.text :content
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    add_index :cluster_reports, [ :cluster_snapshot_id, :created_at ]
    add_index :cluster_reports, :status
  end
end

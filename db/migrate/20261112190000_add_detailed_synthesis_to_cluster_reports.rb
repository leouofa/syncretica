# frozen_string_literal: true

class AddDetailedSynthesisToClusterReports < ActiveRecord::Migration[8.1]
  def change
    add_column :cluster_reports, :is_detailed, :boolean, default: false, null: false
    add_column :cluster_reports, :batch_size, :integer
    add_column :cluster_reports, :total_batches_count, :integer, default: 0, null: false
    add_column :cluster_reports, :aggregated_batches_count, :integer, default: 0, null: false

    create_table :cluster_sub_reports do |t|
      t.references :cluster_report, null: false, foreign_key: { on_delete: :cascade }
      t.references :chat, null: true, foreign_key: { on_delete: :nullify }
      t.integer :batch_index, null: false, default: 1
      t.jsonb :cluster_group_ids, null: false, default: []
      t.text :content, null: false

      t.timestamps
    end

    add_index :cluster_sub_reports, [ :cluster_report_id, :batch_index ], unique: true
  end
end

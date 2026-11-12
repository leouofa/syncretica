# frozen_string_literal: true

class CreateClusterReportSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :cluster_report_summaries do |t|
      t.references :cluster_report, null: false, foreign_key: { on_delete: :cascade }
      t.references :cluster_group, null: false, foreign_key: { on_delete: :cascade }
      t.references :chat, null: true, foreign_key: { on_delete: :nullify }
      t.integer :position, null: false, default: 1
      t.text :content, null: false

      t.timestamps
    end

    add_index :cluster_report_summaries, [ :cluster_report_id, :cluster_group_id ], unique: true
    add_index :cluster_report_summaries, [ :cluster_report_id, :position ]

    add_column :cluster_reports, :phase, :string, default: "queued", null: false
    add_column :cluster_reports, :summarized_clusters_count, :integer, default: 0, null: false
    add_column :cluster_reports, :total_clusters_count, :integer, default: 0, null: false
  end
end

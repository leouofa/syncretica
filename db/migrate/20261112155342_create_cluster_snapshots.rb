# frozen_string_literal: true

class CreateClusterSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :cluster_snapshots do |t|
      t.string :target_type, null: false
      t.integer :level, null: false
      t.float :distance_threshold, null: false
      t.string :title, null: false
      t.integer :clusters_count, default: 0, null: false
      t.integer :items_count, default: 0, null: false

      t.timestamps
    end

    create_table :cluster_groups do |t|
      t.references :cluster_snapshot, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.jsonb :shared_themes, default: [], null: false
      t.integer :size, default: 0, null: false

      t.timestamps
    end

    create_table :cluster_memberships do |t|
      t.references :cluster_group, null: false, foreign_key: { on_delete: :cascade }
      t.references :record, polymorphic: true, null: false

      t.timestamps
    end

    add_index :cluster_snapshots, [ :target_type, :created_at ]
    add_index :cluster_memberships, [ :record_type, :record_id ] unless index_exists?(:cluster_memberships, [ :record_type, :record_id ])
  end
end

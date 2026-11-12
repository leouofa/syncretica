# frozen_string_literal: true

class EnablePgvectorAndAddEmbeddings < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    %i[gods myths].each do |table_name|
      change_table table_name, bulk: true do |t|
        t.column :embedding, :vector, limit: 1024
        t.string :embedding_model
        t.datetime :embedded_at
      end

      add_index table_name, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    end
  end
end

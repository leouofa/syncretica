class CreateChats < ActiveRecord::Migration[8.1]
  def change
    create_table :chats, id: :bigint do |t|
      t.references :ruby_llm_model, null: false, foreign_key: { to_table: :ruby_llm_models }, type: :bigint
      t.boolean :cancelled, null: false, default: false
      t.string :claim_token
      t.datetime :claimed_until
      t.timestamps

      t.index :claimed_until, where: "claim_token IS NOT NULL"
    end
  end
end

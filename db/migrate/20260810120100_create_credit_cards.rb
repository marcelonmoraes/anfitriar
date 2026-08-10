class CreateCreditCards < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_cards do |t|
      t.references :host, null: false, foreign_key: true
      t.string :asaas_token, null: false
      t.string :brand, null: false
      t.string :last_four, null: false
      t.string :holder_name, null: false
      t.integer :expiry_month, null: false
      t.integer :expiry_year, null: false
      t.datetime :default_since

      t.timestamps
    end

    add_index :credit_cards, [ :host_id, :asaas_token ], unique: true
    add_index :credit_cards, [ :host_id, :default_since ]
  end
end

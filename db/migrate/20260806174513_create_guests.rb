class CreateGuests < ActiveRecord::Migration[8.1]
  def change
    create_table :guests do |t|
      t.references :host, null: false, foreign_key: true
      t.string :name, null: false
      t.string :cpf, null: false
      t.string :phone, null: false
      t.string :email

      t.timestamps
    end

    add_index :guests, [ :host_id, :cpf ], unique: true
  end
end

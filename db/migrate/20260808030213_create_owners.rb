class CreateOwners < ActiveRecord::Migration[8.1]
  def change
    create_table :owners do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :owners, :email_address, unique: true
  end
end
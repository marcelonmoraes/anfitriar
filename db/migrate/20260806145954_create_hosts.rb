class CreateHosts < ActiveRecord::Migration[8.1]
  def change
    create_table :hosts do |t|
      t.string :name, null: false
      t.string :email_address, null: false, index: { unique: true }
      t.string :phone, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
  end
end

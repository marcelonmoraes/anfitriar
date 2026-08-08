class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.references :host, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address, null: false

      t.timestamps
    end
  end
end

class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :property, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.boolean :hidden, null: false, default: false
      t.integer :position

      t.timestamps
    end

    add_index :cards, [ :property_id, :category_id ], unique: true
  end
end

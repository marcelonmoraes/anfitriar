class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :slug, null: false, index: { unique: true }
      t.string :name, null: false, index: { unique: true }
      t.integer :monthly_price_cents, null: false
      t.integer :quarterly_price_cents, null: false
      t.integer :semiannual_price_cents, null: false
      t.integer :annual_price_cents, null: false
      t.integer :max_properties

      t.timestamps
    end
  end
end

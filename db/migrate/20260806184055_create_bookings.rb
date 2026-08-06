class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :property, null: false, foreign_key: true
      t.references :guest, null: false, foreign_key: true
      t.date :check_in, null: false
      t.date :check_out, null: false
      t.string :access_token, null: false, index: { unique: true }
      t.datetime :revoked_at

      t.timestamps
    end
  end
end

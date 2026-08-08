class CreatePlatformConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_configurations do |t|
      t.integer :trial_days, null: false, default: 7
      t.integer :booking_access_margin_days, null: false, default: 2

      t.timestamps
    end
  end
end

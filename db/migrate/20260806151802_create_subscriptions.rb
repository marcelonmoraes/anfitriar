class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :host, null: false, foreign_key: true, index: { unique: true }
      t.references :plan, null: false, foreign_key: true
      t.string :status, null: false, default: "trial"
      t.string :billing_cycle
      t.datetime :trial_ends_at

      t.timestamps
    end
  end
end

class AddAsaasFieldsToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :asaas_id, :string
    add_column :subscriptions, :asaas_customer_id, :string
    add_column :subscriptions, :asaas_subscription_id, :string
    add_column :subscriptions, :payment_method, :string
    add_column :subscriptions, :current_period_start, :datetime
    add_column :subscriptions, :current_period_end, :datetime
    add_column :subscriptions, :cancelled_at, :datetime
    add_column :subscriptions, :canceled_by, :string

    add_index :subscriptions, :asaas_id, unique: true
    add_index :subscriptions, :asaas_customer_id
    add_index :subscriptions, :asaas_subscription_id
  end
end

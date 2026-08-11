class NormalizeSubscriptionAsaasFields < ActiveRecord::Migration[8.1]
  def change
    # asaas_id duplicava asaas_subscription_id.
    remove_index :subscriptions, :asaas_id
    remove_column :subscriptions, :asaas_id, :string

    # asaas_customer_id passa a viver em hosts (um customer por anfitrião).
    remove_index :subscriptions, :asaas_customer_id
    remove_column :subscriptions, :asaas_customer_id, :string

    # Grafia alinhada ao enum `canceled`.
    rename_column :subscriptions, :cancelled_at, :canceled_at

    # Cobrança é sempre por cartão de crédito recorrente.
    remove_column :subscriptions, :payment_method, :string

    add_reference :subscriptions, :credit_card, foreign_key: true, null: true
    change_column_null :subscriptions, :asaas_subscription_id, true
    add_index :subscriptions, :asaas_subscription_id, unique: true,
              name: "index_subscriptions_on_asaas_subscription_id_unique"
    remove_index :subscriptions, :asaas_subscription_id,
                 name: "index_subscriptions_on_asaas_subscription_id"
  end
end

class CreateAsaasWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :asaas_webhook_events do |t|
      t.string :event_type, null: false
      t.string :asaas_event_id, null: false
      t.jsonb :payload, null: false
      t.datetime :processed_at
      t.text :error_message
      t.references :subscription, null: true, foreign_key: true

      t.timestamps
    end

    add_index :asaas_webhook_events, :asaas_event_id, unique: true
    add_index :asaas_webhook_events, :event_type
    add_index :asaas_webhook_events, :processed_at
  end
end

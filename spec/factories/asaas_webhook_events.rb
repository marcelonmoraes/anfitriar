FactoryBot.define do
  factory :asaas_webhook_event do
    sequence(:asaas_event_id) { |n| "evt_#{n}" }
    event_type { "PAYMENT_CONFIRMED" }
    payload do
      {
        "id" => asaas_event_id,
        "event" => event_type,
        "payment" => { "subscription" => "sub_123", "paymentDate" => Date.current.to_s }
      }
    end
  end
end

FactoryBot.define do
  factory :host do
    name { "Ana Anfitriã" }
    sequence(:email_address) { |n| "ana#{n}@example.com" }
    phone { "11987654321" }
    password { "senha-segura-123" }
  end
end

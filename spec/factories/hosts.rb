FactoryBot.define do
  factory :host do
    name { "Ana Anfitriã" }
    sequence(:email_address) { |n| "ana#{n}@example.com" }
    phone { "11987654321" }
    password { "senha-segura-123" }

    trait :with_billing_profile do
      cpf_cnpj { "52998224725" }
      postal_code { "01310000" }
      address_number { "1000" }
    end
  end
end

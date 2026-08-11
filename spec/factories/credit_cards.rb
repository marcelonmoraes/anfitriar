FactoryBot.define do
  factory :credit_card do
    host
    sequence(:asaas_token) { |n| "tok_#{n}" }
    brand { "VISA" }
    last_four { "4242" }
    holder_name { "ANA ANFITRIA" }
    expiry_month { 12 }
    expiry_year { Date.current.year + 3 }

    trait :expired do
      expiry_month { 1 }
      expiry_year { Date.current.year - 1 }
    end
  end
end

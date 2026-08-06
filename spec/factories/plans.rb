FactoryBot.define do
  factory :plan do
    sequence(:slug) { |n| "plano-#{n}" }
    sequence(:name) { |n| "Plano #{n}" }
    monthly_price_cents { 1990 }
    quarterly_price_cents { 5373 }
    semiannual_price_cents { 10_149 }
    annual_price_cents { 17_910 }
    max_properties { nil }

    trait :limited do
      max_properties { 1 }
    end
  end
end

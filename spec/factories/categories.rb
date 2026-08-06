FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Categoria #{n}" }
    sequence(:position)
    host { nil }

    trait :own do
      host
      position { nil }
    end
  end
end

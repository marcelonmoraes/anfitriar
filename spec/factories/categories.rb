FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Categoria #{n}" }
    sequence(:position)
    host { nil }

    trait :own do
      association :host, strategy: :create
      position { nil }
    end
  end
end

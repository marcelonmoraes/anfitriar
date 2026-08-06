FactoryBot.define do
  factory :card do
    property
    category
    description { "<p>Conteúdo do card</p>" }
    hidden { false }
  end
end

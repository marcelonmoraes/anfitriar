FactoryBot.define do
  factory :property do
    host
    sequence(:name) { |n| "Apê da Praia #{n}" }
    address { "Rua das Gaivotas, 100 — Florianópolis/SC" }
  end
end

FactoryBot.define do
  factory :guest do
    host
    name { "Carlos Hóspede" }
    sequence(:cpf) { |n| CpfValidator.generate(n) }
    phone { "11912345678" }
  end
end

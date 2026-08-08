FactoryBot.define do
  factory :owner do
    sequence(:name) { |n| "Admin #{n}" }
    sequence(:email_address) { |n| "admin#{n}@anfitriar.com" }
    password { "senha-admin-123" }
    password_confirmation { "senha-admin-123" }
  end
end
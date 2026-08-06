FactoryBot.define do
  factory :subscription do
    host
    plan
    status { "trial" }
    trial_ends_at { 7.days.from_now }
  end
end

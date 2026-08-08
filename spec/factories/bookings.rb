FactoryBot.define do
  factory :booking do
    property
    guest { association :guest, host: property.host }
    check_in { Date.current }
    check_out { Date.current + 3 }
  end
end

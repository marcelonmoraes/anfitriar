class PlatformConfiguration < ApplicationRecord
  validates :trial_days, :booking_access_margin_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.current
    first_or_create!
  end
end

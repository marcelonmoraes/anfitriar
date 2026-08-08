class Plan < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_error

  validates :slug, :name, presence: true, uniqueness: true
  validates :monthly_price_cents, :quarterly_price_cents, :semiannual_price_cents, :annual_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_properties, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end

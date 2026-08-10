class CreditCard < ApplicationRecord
  belongs_to :host
  has_many :subscriptions, dependent: :nullify

  validates :asaas_token, presence: true, uniqueness: { scope: :host_id }
  validates :brand, :holder_name, presence: true
  validates :last_four, format: { with: /\A\d{4}\z/ }
  validates :expiry_month, inclusion: { in: 1..12 }
  validates :expiry_year, numericality: { greater_than_or_equal_to: 2000 }

  scope :default_first, -> { order(Arel.sql("default_since DESC NULLS LAST"), created_at: :desc) }

  after_create_commit :make_default, if: :first_card?

  def default?
    default_since.present?
  end

  def make_default!
    transaction do
      host.credit_cards.where.not(id: id).update_all(default_since: nil)
      update!(default_since: Time.current)
    end
  end

  def expired?
    Date.new(expiry_year, expiry_month, 1).end_of_month < Date.current
  end

  def expires_on
    format("%02d/%s", expiry_month, expiry_year.to_s.last(2))
  end

  def to_s
    "#{brand} •••• #{last_four}"
  end

  private
    def first_card?
      host.credit_cards.count == 1
    end

    def make_default
      update_column(:default_since, Time.current)
    end
end

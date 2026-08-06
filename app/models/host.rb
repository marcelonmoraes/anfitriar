class Host < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :subscription, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :phone, with: ->(p) { p.gsub(/\D/, "") }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true,
            format: { with: /\A\d{10,11}\z/, message: "deve ter DDD + número (10 ou 11 dígitos)" }
end

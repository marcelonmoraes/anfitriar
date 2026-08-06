class Guest < ApplicationRecord
  belongs_to :host

  encrypts :cpf, deterministic: true
  encrypts :phone

  normalizes :cpf, with: ->(c) { c.gsub(/\D/, "") }
  normalizes :phone, with: ->(p) { p.gsub(/\D/, "") }
  normalizes :email, with: ->(e) { e.strip.downcase.presence }

  validates :name, presence: true
  validates :cpf, presence: true, cpf: true, uniqueness: { scope: :host_id }
  validates :phone, presence: true,
            format: { with: /\A\d{10,11}\z/, message: "deve ter DDD + número (10 ou 11 dígitos)" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  def masked_cpf
    "***.#{cpf[3..5]}.#{cpf[6..8]}-**"
  end

  def phone_last_digits(count = 4)
    phone.last(count)
  end
end

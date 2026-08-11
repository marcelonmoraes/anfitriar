class Host < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :credit_cards, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :properties, dependent: :destroy
  has_many :guests, dependent: :destroy
  has_many :bookings, through: :properties

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :phone, with: ->(p) { p.gsub(/\D/, "") }
  normalizes :cpf_cnpj, with: ->(d) { d.gsub(/\D/, "") }
  normalizes :postal_code, with: ->(p) { p.gsub(/\D/, "") }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true,
            format: { with: /\A\d{10,11}\z/, message: "deve ter DDD + número (10 ou 11 dígitos)" }
  validates :cpf_cnpj, format: { with: /\A(\d{11}|\d{14})\z/, message: "deve ser um CPF ou CNPJ válido" },
            allow_blank: true
  validates :postal_code, format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }, allow_blank: true

  # Memoizado para que listagens com muitas hospedagens não repitam a consulta
  # de categorias uma vez por hospedagem. Usa a associação já pré-carregada
  # quando existe, evitando uma ida ao banco por anfitrião.
  def available_categories
    @available_categories ||=
      Category.standard_ordered + categories.sort_by { |category| category.name.to_s }
  end

  # Média de preenchimento dos guias, em porcentagem. Calculada aqui para que a
  # listagem do admin consiga pré-carregar cards e categorias numa consulta só.
  def average_guide_completion
    return 0 if properties.empty?

    total = properties.sum { |property| property.guide_completion_percentage }
    (total / properties.size).round
  end

  # Dados que o Asaas exige para tokenizar um cartão em nome do anfitrião.
  def billing_profile_complete?
    cpf_cnpj.present? && postal_code.present? && address_number.present?
  end

  def default_credit_card
    credit_cards.default_first.first
  end
end

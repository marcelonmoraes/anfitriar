# frozen_string_literal: true

# Objeto de formulário do checkout. Existe só durante a requisição:
# valida os dados do cartão e os entrega ao Asaas para tokenização.
# Nada aqui é persistido.
class CreditCardForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :holder_name, :string
  attribute :number, :string
  attribute :expiry, :string
  attribute :cvv, :string
  attribute :document, :string

  validates :holder_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :number, presence: true
  validates :cvv, presence: true, format: { with: /\A\d{3,4}\z/, message: "deve ter 3 ou 4 dígitos" }
  validate :number_must_be_valid
  validate :expiry_must_be_valid
  validate :document_must_be_valid

  def number=(value)
    super(value.to_s.gsub(/\D/, ""))
  end

  def cvv=(value)
    super(value.to_s.gsub(/\D/, ""))
  end

  def document=(value)
    super(value.to_s.gsub(/\D/, ""))
  end

  def expiry_month
    expiry_parts.first&.to_i
  end

  def expiry_year
    year = expiry_parts.second
    return if year.blank?

    year.length == 2 ? "20#{year}".to_i : year.to_i
  end

  # Nunca exponha o cartão em logs ou inspeções.
  def inspect
    "#<CreditCardForm holder_name=#{holder_name.inspect} last_four=#{number.to_s.last(4).inspect}>"
  end
  alias to_s inspect

  private
    def expiry_parts
      expiry.to_s.gsub(/[^\d]/, "/").split("/").reject(&:blank?)
    end

    def number_must_be_valid
      return if number.blank?

      if number.length < 13 || number.length > 19
        errors.add(:number, "deve ter entre 13 e 19 dígitos")
      elsif !luhn_valid?(number) && Rails.env.production?
        errors.add(:number, "é inválido")
      end
    end

    def expiry_must_be_valid
      month, year = expiry_month, expiry_year

      if month.nil? || year.nil? || expiry_parts.size != 2
        errors.add(:expiry, "deve estar no formato MM/AA")
      elsif !month.between?(1, 12)
        errors.add(:expiry, "tem mês inválido")
      elsif Date.new(year, month, 1).end_of_month < Date.current
        errors.add(:expiry, "está vencida")
      end
    rescue Date::Error
      errors.add(:expiry, "é inválida")
    end

    def document_must_be_valid
      return if document.blank?
      return if document.length.in?([ 11, 14 ])

      errors.add(:document, "deve ser um CPF ou CNPJ válido")
    end

    def luhn_valid?(digits)
      sum = digits.chars.reverse.each_with_index.sum do |char, index|
        value = char.to_i
        next value unless index.odd?

        doubled = value * 2
        doubled > 9 ? doubled - 9 : doubled
      end

      (sum % 10).zero?
    end
end

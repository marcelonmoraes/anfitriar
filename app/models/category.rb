class Category < ApplicationRecord
  belongs_to :host, optional: true
  has_many :cards, dependent: :destroy

  scope :standard, -> { where(host_id: nil) }
  scope :ordered, -> { order(:position, :name) }

  validates :name, presence: true, uniqueness: { scope: :host_id }

  def self.available_to(host)
    standard.ordered + where(host: host).order(:name)
  end

  # As categorias padrão são idênticas para todos os anfitriões e mudam apenas
  # pelo Admin. Cachear por requisição evita repetir a mesma consulta uma vez
  # por anfitrião nas listagens.
  def self.standard_ordered
    Current.standard_categories ||= standard.ordered.to_a
  end

  def standard?
    host_id.nil?
  end
end

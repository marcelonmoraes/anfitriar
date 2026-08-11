class Property < ApplicationRecord
  belongs_to :host
  has_one_attached :cover_photo
  has_many :cards, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_rich_text :description

  validates :name, :address, presence: true
  validate :within_plan_limit, on: :create

  def guide_entries
    existing = cards.by_position.includes(:category, :rich_text_description).to_a
    remaining = host.available_categories - existing.map(&:category)
    existing.map { |card| [ card.category, card ] } + remaining.map { |category| [ category, nil ] }
  end

  def guide_progress
    categories = host.available_categories
    filled = cards.filter(&:filled?).count { |card| categories.include?(card.category) }
    { filled: filled, total: categories.size }
  end

  def guide_completion_percentage
    progress = guide_progress
    return 0 unless progress[:total].positive?

    progress[:filled].to_f / progress[:total] * 100
  end

  def visible_cards
    cards.by_position.includes(:category, :rich_text_description).reject(&:hidden?).select(&:filled?)
  end

  private
    def within_plan_limit
      return if host.nil?

      limit = host.subscription&.plan&.max_properties
      return if limit.nil?

      if host.properties.count >= limit
        errors.add(:base, "Você atingiu o limite de #{limit} hospedagens do seu plano. Fale com a gente para fazer upgrade.")
      end
    end
end

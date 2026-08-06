class Card < ApplicationRecord
  belongs_to :property
  belongs_to :category

  has_rich_text :description

  validates :category_id, uniqueness: { scope: :property_id }

  scope :by_position, -> { order(position: :asc, id: :asc) }

  def filled?
    description.present?
  end

  def self.upsert_for(property, category, attributes)
    card = property.cards.find_or_initialize_by(category: category)
    card.update(attributes)
    card
  end
end

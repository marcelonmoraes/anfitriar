class Property < ApplicationRecord
  belongs_to :host
  has_one_attached :cover_photo

  validates :name, :address, presence: true
  validate :within_plan_limit, on: :create

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

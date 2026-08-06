class Category < ApplicationRecord
  belongs_to :host, optional: true

  scope :standard, -> { where(host_id: nil) }
  scope :ordered, -> { order(:position, :name) }

  validates :name, presence: true, uniqueness: { scope: :host_id }

  def self.available_to(host)
    standard.ordered + where(host: host).order(:name)
  end

  def standard?
    host_id.nil?
  end
end

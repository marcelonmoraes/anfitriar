# frozen_string_literal: true

class AsaasWebhookEvent < ApplicationRecord
  belongs_to :subscription, optional: true

  validates :event_type, presence: true
  validates :asaas_event_id, presence: true, uniqueness: true
  validates :payload, presence: true

  scope :processed, -> { where.not(processed_at: nil) }
  scope :pending, -> { where(processed_at: nil) }
  scope :failed, -> { where.not(error_message: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def processed?
    processed_at.present?
  end

  def failed?
    error_message.present?
  end

  def mark_processed!
    update!(processed_at: Time.current, error_message: nil)
  end

  def mark_failed!(error)
    update!(error_message: error.to_s)
  end
end

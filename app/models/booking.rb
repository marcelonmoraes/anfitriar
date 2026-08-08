class Booking < ApplicationRecord
  belongs_to :property
  belongs_to :guest

  has_secure_token :access_token

  scope :within_window, -> {
    where(check_out: (Date.current - PlatformConfiguration.current.booking_access_margin_days)..)
  }
  scope :finished, -> {
    where(check_out: ...(Date.current - PlatformConfiguration.current.booking_access_margin_days))
  }
  scope :recent_first, -> { order(check_in: :desc) }

  validates :check_in, :check_out, presence: true
  validate :check_out_after_check_in
  validate :guest_belongs_to_property_host

  def accessible_until
    check_out + PlatformConfiguration.current.booking_access_margin_days
  end

  def revoked?
    revoked_at.present?
  end

  def link_active?
    !revoked? && Date.current <= accessible_until
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def reissue!
    regenerate_access_token
    update!(revoked_at: nil)
  end

  def verify_guest!(cpf, phone_last4)
    normalized_cpf = cpf.gsub(/\D/, "")
    normalized_phone = phone_last4.to_s.last(4)

    guest.cpf == normalized_cpf && guest.phone_last_digits(4) == normalized_phone
  end

  private
    def check_out_after_check_in
      return if check_in.blank? || check_out.blank?
      errors.add(:check_out, "deve ser depois do check-in") if check_out <= check_in
    end

    def guest_belongs_to_property_host
      return if guest.nil? || property.nil?
      errors.add(:guest, "não pertence à sua conta") if guest.host_id != property.host_id
    end
end

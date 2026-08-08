class PublicGuidesController < ApplicationController
  allow_unauthenticated_access
  layout "public_guide"

  before_action :set_booking
  before_action :check_booking_validity, only: %i[show verify verify_submit]
  before_action :require_verification, only: %i[show]

  def show
    @cards = @booking.property.visible_cards
  end

  def verify
  end

  def verify_submit
    if @booking.verify_guest!(params[:cpf], params[:phone_last4])
      set_verification_cookie
      redirect_to public_guide_path(@booking.access_token)
    else
      flash.now[:alert] = "O CPF ou os 4 dígitos do telefone não conferem. Verifique e tente novamente."
      render :verify, status: :unprocessable_content
    end
  end

  private

  def set_booking
    @booking = Booking.includes(:guest, property: :cards).find_by(access_token: params[:token])
  end

  def check_booking_validity
    return if @booking&.link_active?

    render :invalid_link, status: :not_found
  end

  def require_verification
    return if verified_guest?

    redirect_to verify_public_guide_path(@booking.access_token)
  end

  def verified_guest?
    cookies.signed["guest_access_#{@booking.access_token}"].present?
  end

  def set_verification_cookie
    cookies.signed["guest_access_#{@booking.access_token}"] = {
      value: @booking.access_token,
      expires: @booking.accessible_until,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
  end
end
class BookingsController < ApplicationController
  def index
    bookings = Current.host.bookings.includes(:property, :guest)
    @current_bookings = bookings.within_window.recent_first
    @finished_bookings = bookings.finished.recent_first
  end

  def new
    @booking = Booking.new
  end

  def create
    @booking = Booking.new(booking_attributes)
    if @booking.save
      redirect_to @booking, notice: "Reserva criada. Envie o link ao hóspede."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @booking = Current.host.bookings.find(params[:id])
  end

  def revoke
    booking = Current.host.bookings.find(params[:id])
    booking.revoke!
    redirect_to booking, notice: "Link revogado. O hóspede perdeu o acesso."
  end

  def reissue
    booking = Current.host.bookings.find(params[:id])
    booking.reissue!
    redirect_to booking, notice: "Novo link gerado. O anterior deixou de funcionar."
  end

  private
    def booking_attributes
      permitted = params.expect(booking: [ :property_id, :guest_id, :check_in, :check_out ])
      {
        property: Current.host.properties.find(permitted[:property_id]),
        guest: Current.host.guests.find(permitted[:guest_id]),
        check_in: permitted[:check_in],
        check_out: permitted[:check_out]
      }
    end
end

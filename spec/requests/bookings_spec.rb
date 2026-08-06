require "rails_helper"

RSpec.describe "Reservas", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let!(:guest) { create(:guest, host: host) }

  before { sign_in host }

  it "cria reserva e mostra o link de acesso" do
    expect {
      post bookings_path, params: { booking: {
        property_id: property.id, guest_id: guest.id,
        check_in: Date.current, check_out: Date.current + 3
      } }
    }.to change(Booking, :count).by(1)

    booking = Booking.last
    follow_redirect!
    expect(response.body).to include(booking.access_token)
    expect(response.body).to include("wa.me/55#{guest.phone}")
  end

  it "rejeita hospedagem ou cliente de outro anfitrião (404)" do
    foreign_property = create(:property)
    post bookings_path, params: { booking: {
      property_id: foreign_property.id, guest_id: guest.id,
      check_in: Date.current, check_out: Date.current + 2
    } }
    expect(response).to have_http_status(:not_found)
  end

  it "separa reservas ativas de encerradas no índice" do
    create(:booking, property: property, guest: guest,
           check_in: Date.current, check_out: Date.current + 2)
    create(:booking, property: property, guest: guest,
           check_in: Date.current - 10, check_out: Date.current - 5)

    get bookings_path
    expect(response.body).to include("Ativas e futuras")
    expect(response.body).to include("Encerradas")
  end

  it "revoga e regenera o link" do
    booking = create(:booking, property: property, guest: guest)
    original_token = booking.access_token

    patch revoke_booking_path(booking)
    expect(booking.reload).to be_revoked

    patch reissue_booking_path(booking)
    booking.reload
    expect(booking).not_to be_revoked
    expect(booking.access_token).not_to eq(original_token)
  end

  it "não permite revogar reserva de outro anfitrião (404)" do
    other = create(:booking)
    patch revoke_booking_path(other)
    expect(response).to have_http_status(:not_found)
  end
end

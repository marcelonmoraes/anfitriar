require "rails_helper"

RSpec.describe "Rota pública do guia (placeholder)", type: :request do
  it "responde igual para qualquer token, sem exigir login e sem vazar dados" do
    booking = create(:booking)

    get public_guide_path(token: booking.access_token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("em preparação")
    expect(response.body).not_to include(booking.guest.name)
    expect(response.body).not_to include(booking.property.name)

    get public_guide_path(token: "token-que-nao-existe")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("em preparação")
  end
end

require "rails_helper"

RSpec.describe "Rota pública do guia", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let!(:guest) { create(:guest, host: host, cpf: "39053344705", phone: "11912345678") }
  let!(:booking) { create(:booking, property: property, guest: guest, check_in: Date.current - 1, check_out: Date.current + 3) }

  context "com token válido" do
    it "redireciona para verificação se não houver cookie" do
      get public_guide_path(token: booking.access_token)
      expect(response).to redirect_to(verify_public_guide_path(booking.access_token))
    end

    it "não vaza dados do hóspede na página de verificação" do
      get verify_public_guide_path(booking.access_token)
      expect(response.body).not_to include(guest.name)
      expect(response.body).not_to include(property.name)
      expect(response.body).not_to include(guest.cpf)
      expect(response.body).not_to include(guest.phone)
    end
  end

  context "com token inválido" do
    it "retorna 404 com página neutra" do
      get public_guide_path(token: "token-que-nao-existe")
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Link inválido")
    end
  end

  context "com token revogado" do
    let!(:revoked_booking) { create(:booking, property: property, guest: guest, revoked_at: Time.current) }

    it "retorna 404 com página neutra (não diferencia de inexistente)" do
      get public_guide_path(token: revoked_booking.access_token)
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Link inválido")
    end
  end

  context "com token fora da janela de acesso" do
    let!(:expired_booking) { create(:booking, property: property, guest: guest, check_in: Date.current - 10, check_out: Date.current - 5) }

    it "retorna 404 com página neutra" do
      get public_guide_path(token: expired_booking.access_token)
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Link inválido")
    end
  end
end
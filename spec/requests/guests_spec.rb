require "rails_helper"

RSpec.describe "Clientes", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "lista apenas clientes do anfitrião, com CPF mascarado" do
    create(:guest, host: host, name: "Meu Cliente", cpf: "39053344705")
    create(:guest, name: "Cliente Alheio")

    get guests_path
    expect(response.body).to include("Meu Cliente")
    expect(response.body).to include("***.533.447-**")
    expect(response.body).not_to include("39053344705")
    expect(response.body).not_to include("Cliente Alheio")
  end

  it "cria cliente" do
    expect {
      post guests_path, params: { guest: { name: "Novo", cpf: "390.533.447-05", phone: "11912345678", email: "" } }
    }.to change(host.guests, :count).by(1)
  end

  it "retorna 404 ao editar cliente de outro anfitrião" do
    other = create(:guest)
    get edit_guest_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "exclui cliente definitivamente" do
    guest = create(:guest, host: host)
    expect { delete guest_path(guest) }.to change(Guest, :count).by(-1)
  end
end

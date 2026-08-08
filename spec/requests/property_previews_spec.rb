require "rails_helper"

RSpec.describe "Preview do guia", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }

  before { sign_in host }

  it "mostra apenas cards preenchidos e não ocultos, em ordem" do
    wifi = create(:category, name: "Wi-Fi", position: 1)
    rules = create(:category, name: "Regras da casa", position: 2)
    phones = create(:category, name: "Telefones úteis", position: 3)
    Card.upsert_for(property, wifi, description: "<p>Rede: Casa</p>", position: 1)
    Card.upsert_for(property, rules, description: "<p>Sem festas</p>", position: 2, hidden: true)
    Card.upsert_for(property, phones, description: nil, position: 3)

    get property_preview_path(property)
    expect(response.body).to include("Wi-Fi")
    expect(response.body).to include("Rede: Casa")
    expect(response.body).not_to include("Sem festas")
    expect(response.body).not_to include("Telefones úteis")
  end

  it "exige login (não é a rota pública)" do
    delete session_path
    get property_preview_path(property)
    expect(response).to redirect_to(new_session_path)
  end

  it "rejeita hospedagem de outro anfitrião (404)" do
    other = create(:property)
    get property_preview_path(other)
    expect(response).to have_http_status(:not_found)
  end
end

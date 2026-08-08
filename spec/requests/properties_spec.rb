require "rails_helper"

RSpec.describe "Hospedagens", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "lista apenas as hospedagens do anfitrião logado" do
    mine = create(:property, host: host, name: "Minha Casa")
    create(:property, name: "Casa Alheia")

    get properties_path
    expect(response.body).to include("Minha Casa")
    expect(response.body).not_to include("Casa Alheia")
  end

  it "cria hospedagem para o anfitrião logado" do
    expect {
      post properties_path, params: { property: { name: "Chalé", address: "Serra, 42" } }
    }.to change(host.properties, :count).by(1)
    expect(response).to redirect_to(property_path(host.properties.last))
  end

  it "retorna 404 para hospedagem de outro anfitrião" do
    other = create(:property)
    get property_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "mostra o erro de limite do plano" do
    host.create_subscription!(plan: create(:plan, :limited), status: "trial", trial_ends_at: 7.days.from_now)
    create(:property, host: host)

    post properties_path, params: { property: { name: "Extra", address: "Rua X" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("limite")
  end

  it "exclui hospedagem" do
    property = create(:property, host: host)
    expect { delete property_path(property) }.to change(host.properties, :count).by(-1)
  end
end

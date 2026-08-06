require "rails_helper"

RSpec.describe "Conta", type: :request do
  let!(:host) { create(:host) }

  before do
    create(:subscription, host: host, plan: create(:plan, name: "Pro Teste"), trial_ends_at: 5.days.from_now)
    sign_in host
  end

  it "mostra dados e status da assinatura" do
    get account_path
    expect(response.body).to include(host.name)
    expect(response.body).to include("Pro Teste")
    expect(response.body).to include("Período de teste")
    expect(response.body).to include("5 dias")
  end

  it "atualiza os dados do anfitrião" do
    patch account_path, params: { host: { name: "Novo Nome", phone: "11999998888", email_address: host.email_address } }
    expect(response).to redirect_to(account_path)
    expect(host.reload.name).to eq("Novo Nome")
  end

  it "reexibe com erros quando inválido" do
    patch account_path, params: { host: { name: "", phone: "1", email_address: "x" } }
    expect(response).to have_http_status(:unprocessable_entity)
  end
end

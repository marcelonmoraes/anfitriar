require "rails_helper"

RSpec.describe "Cadastro do anfitrião", type: :request do
  before { create(:plan, slug: "pro", name: "Pro") }

  it "cria conta, inicia trial e loga" do
    expect {
      post registration_path, params: { host: {
        name: "Ana", email_address: "ana@example.com", phone: "11987654321",
        password: "senha-segura-123", password_confirmation: "senha-segura-123"
      } }
    }.to change(Host, :count).by(1).and change(Subscription, :count).by(1)

    host = Host.find_by!(email_address: "ana@example.com")
    expect(host.subscription).to be_trial
    expect(response).to redirect_to(root_path)

    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "reexibe o formulário com erros quando inválido" do
    post registration_path, params: { host: { name: "", email_address: "x", phone: "1",
                                              password: "a", password_confirmation: "b" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Host.count).to eq(0)
  end
end

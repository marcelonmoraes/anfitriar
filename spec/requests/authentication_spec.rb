require "rails_helper"

RSpec.describe "Autenticação", type: :request do
  let!(:host) { create(:host, password: "senha-segura-123") }

  it "faz login com credenciais válidas e cria sessão" do
    post session_path, params: { email_address: host.email_address, password: "senha-segura-123" }
    expect(response).to redirect_to(root_path)
    expect(host.sessions.count).to eq(1)
  end

  it "rejeita credenciais inválidas" do
    post session_path, params: { email_address: host.email_address, password: "errada" }
    expect(response).to redirect_to(new_session_path)
    expect(host.sessions.count).to eq(0)
  end

  it "exige login para a área do anfitrião" do
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "dá acesso após o login e encerra no logout" do
    sign_in host
    get root_path
    expect(response).to have_http_status(:ok)

    delete session_path
    expect(response).to redirect_to(new_session_path)
    expect(host.sessions.count).to eq(0)
  end
end

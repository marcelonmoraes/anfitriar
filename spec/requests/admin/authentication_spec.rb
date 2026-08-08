require "rails_helper"

RSpec.describe "Admin Authentication", type: :request do
  let!(:owner) { create(:owner, password: "senha-admin-123") }

  it "faz login como Owner e acessa o dashboard" do
    sign_in_owner owner
    expect(response).to redirect_to(admin_root_path)
    follow_redirect!
    expect(response.body).to include("Dashboard Administrativo")
  end

  it "rejeita credenciais inválidas" do
    post admin_login_path, params: { email_address: owner.email_address, password: "errada" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("E-mail ou senha inválidos.")
  end

  it "exige login de Owner para acessar rotas /admin" do
    get admin_root_path
    expect(response).to redirect_to(admin_login_path)
  end

  it "impede que um Host comum acesse rotas /admin" do
    host = create(:host)
    sign_in host # login de host na sessão de anfitrião
    get admin_root_path
    expect(response).to redirect_to(admin_login_path)
  end

  it "faz logout do Owner" do
    sign_in_owner owner
    delete admin_logout_path
    expect(response).to redirect_to(admin_login_path)
  end
end
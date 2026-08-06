require "rails_helper"

RSpec.describe "Recuperação de senha", type: :request do
  let!(:host) { create(:host) }

  it "envia e-mail quando o endereço existe, com resposta idêntica quando não existe" do
    expect {
      post passwords_path, params: { email_address: host.email_address }
    }.to have_enqueued_mail(PasswordsMailer, :reset)
    expect(response).to redirect_to(new_session_path)

    expect {
      post passwords_path, params: { email_address: "nao-existe@example.com" }
    }.not_to have_enqueued_mail
    expect(response).to redirect_to(new_session_path)
  end

  it "redefine a senha com token válido e derruba sessões antigas" do
    sign_in host
    token = host.password_reset_token

    patch password_path(token), params: { host: {
      password: "nova-senha-123", password_confirmation: "nova-senha-123"
    } }

    expect(response).to redirect_to(new_session_path)
    expect(host.reload.authenticate("nova-senha-123")).to be_truthy
    expect(host.sessions.count).to eq(0)
  end

  it "rejeita token inválido" do
    patch password_path("token-invalido"), params: { host: {
      password: "nova-senha-123", password_confirmation: "nova-senha-123"
    } }
    expect(response).to redirect_to(new_password_path)
  end
end

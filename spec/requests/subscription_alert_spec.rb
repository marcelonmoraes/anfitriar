require "rails_helper"

RSpec.describe "Aviso de assinatura no topo", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "alerta quando o teste está acabando" do
    create(:subscription, host: host, status: :trial, trial_ends_at: 2.days.from_now)

    get properties_path

    expect(response.body).to include("Seu teste termina em")
  end

  it "alerta quando o teste terminou" do
    create(:subscription, host: host, status: :trial, trial_ends_at: 1.day.ago)

    get properties_path

    expect(response.body).to include("Seu teste terminou")
  end

  it "alerta quando o pagamento falhou" do
    create(:subscription, host: host, status: :past_due, trial_ends_at: nil)

    get properties_path

    expect(response.body).to include("Pagamento pendente")
  end

  it "não incomoda quem está em dia" do
    create(:subscription, host: host, status: :active, trial_ends_at: nil)

    get properties_path

    expect(response.body).not_to include("Pagamento pendente")
    expect(response.body).not_to include("Seu teste termina")
  end

  it "não incomoda quem ainda tem bastante tempo de teste" do
    create(:subscription, host: host, status: :trial, trial_ends_at: 10.days.from_now)

    get properties_path

    expect(response.body).not_to include("Seu teste termina")
  end
end

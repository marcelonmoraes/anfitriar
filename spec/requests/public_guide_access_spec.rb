require "rails_helper"

RSpec.describe "Acesso ao guia conforme a assinatura", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let!(:guest) { create(:guest, host: host, cpf: "39053344705", phone: "11912345678") }
  let!(:booking) do
    create(:booking, property: property, guest: guest,
                     check_in: Date.current - 1, check_out: Date.current + 3)
  end

  def get_guide
    get verify_public_guide_path(booking.access_token)
  end

  it "libera o guia durante o teste grátis" do
    create(:subscription, host: host, status: :trial, trial_ends_at: 3.days.from_now)

    get_guide

    expect(response).to have_http_status(:ok)
  end

  it "libera o guia com assinatura ativa" do
    create(:subscription, host: host, status: :active, trial_ends_at: nil)

    get_guide

    expect(response).to have_http_status(:ok)
  end

  it "mantém o guia no ar enquanto tentamos recuperar o pagamento" do
    create(:subscription, host: host, status: :past_due, trial_ends_at: nil)

    get_guide

    expect(response).to have_http_status(:ok)
  end

  it "tira o guia do ar quando o teste expira" do
    create(:subscription, host: host, status: :trial, trial_ends_at: 1.day.ago)

    get_guide

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include("Guia temporariamente indisponível")
  end

  it "tira o guia do ar quando a assinatura é cancelada" do
    create(:subscription, host: host, status: :canceled, trial_ends_at: nil)

    get_guide

    expect(response).to have_http_status(:service_unavailable)
  end

  it "não vaza dados do hóspede na página de indisponibilidade" do
    create(:subscription, host: host, status: :canceled, trial_ends_at: nil)

    get_guide

    expect(response.body).not_to include(guest.name)
    expect(response.body).not_to include(property.name)
  end
end

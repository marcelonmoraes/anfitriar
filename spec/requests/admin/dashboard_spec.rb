require "rails_helper"

RSpec.describe "Dashboard administrativo", type: :request do
  let!(:owner) { create(:owner) }
  let!(:plan) { create(:plan, slug: "pro", monthly_price_cents: 5000, annual_price_cents: 45_000) }

  before { sign_in_owner owner }

  it "soma o MRR de quem gera receita hoje" do
    create(:subscription, plan: plan, status: :active, billing_cycle: :monthly, trial_ends_at: nil)
    create(:subscription, plan: plan, status: :past_due, billing_cycle: :annual, trial_ends_at: nil)
    create(:subscription, plan: plan, status: :trial)
    create(:subscription, plan: plan, status: :canceled, billing_cycle: :monthly, trial_ends_at: nil)

    get admin_root_path

    # 5000 (mensal ativa) + 3750 (anual inadimplente) — trial e cancelada ficam de fora.
    expect(response.body).to include("R$ 87,50")
    expect(response.body).to include("R$ 1.050,00")
  end

  it "calcula a conversão sobre quem já saiu do teste" do
    create(:subscription, plan: plan, status: :active, billing_cycle: :monthly, trial_ends_at: nil)
    create(:subscription, plan: plan, status: :canceled, billing_cycle: :monthly, trial_ends_at: nil)
    create(:subscription, plan: plan, status: :trial)

    get admin_root_path

    expect(response.body).to include("50.0%")
  end

  it "não divide por zero quando ninguém saiu do teste" do
    create(:subscription, plan: plan, status: :trial)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("0%")
  end

  it "destaca webhooks que falharam para o Owner agir" do
    event = create(:asaas_webhook_event)
    event.mark_failed!("Timeout no Asaas")

    get admin_root_path

    expect(response.body).to include("Webhooks com falha")
    expect(response.body).to include("Timeout no Asaas")
  end

  it "não mostra o alerta quando está tudo processado" do
    create(:asaas_webhook_event).mark_processed!

    get admin_root_path

    expect(response.body).not_to include("Webhooks com falha")
  end
end

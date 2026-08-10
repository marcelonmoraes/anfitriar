require "rails_helper"

RSpec.describe "Admin sincronizando assinatura com o Asaas", type: :request do
  let!(:owner) { create(:owner) }
  let!(:host) { create(:host) }
  let!(:plan) { create(:plan, slug: "pro", name: "Pro") }
  let!(:outro_plano) { create(:plan, name: "Max", monthly_price_cents: 9990) }

  before { sign_in_owner owner }

  def subscription_with_asaas(**overrides)
    create(:subscription, { host: host, plan: plan, status: :active, billing_cycle: :monthly,
                            asaas_subscription_id: "sub_1", trial_ends_at: nil }.merge(overrides))
  end

  it "replica a troca de plano no Asaas" do
    client = fake_asaas_client
    subscription_with_asaas

    patch admin_host_subscription_path(host), params: {
      subscription: { plan_id: outro_plano.id, billing_cycle: "monthly", status: "active" }
    }

    expect(client).to be_called(:update_subscription)
    expect(host.reload.subscription.plan).to eq(outro_plano)
  end

  it "replica o cancelamento no Asaas registrando o admin" do
    client = fake_asaas_client
    subscription_with_asaas

    patch admin_host_subscription_path(host), params: {
      subscription: { plan_id: plan.id, billing_cycle: "monthly", status: "canceled" }
    }

    expect(client).to be_called(:cancel_subscription)
    expect(host.reload.subscription).to be_canceled_by_admin
  end

  it "não chama o Asaas quando nada relevante muda" do
    client = fake_asaas_client
    subscription_with_asaas

    patch admin_host_subscription_path(host), params: {
      subscription: { plan_id: plan.id, billing_cycle: "monthly", status: "active" }
    }

    expect(client).not_to be_called(:update_subscription)
    expect(client).not_to be_called(:cancel_subscription)
  end

  it "não chama o Asaas para assinatura que só existe localmente" do
    client = fake_asaas_client
    create(:subscription, host: host, plan: plan, status: :trial, asaas_subscription_id: nil)

    patch admin_host_subscription_path(host), params: {
      subscription: { plan_id: outro_plano.id, billing_cycle: "annual", status: "trial" }
    }

    expect(client.calls).to be_empty
    expect(host.reload.subscription.plan).to eq(outro_plano)
  end

  it "preserva a alteração local e avisa quando o Asaas recusa" do
    client = fake_asaas_client
    allow(client).to receive(:update_subscription).and_raise(
      Asaas::Client::InvalidRequestError.new("Assinatura já encerrada.")
    )
    subscription_with_asaas

    patch admin_host_subscription_path(host), params: {
      subscription: { plan_id: outro_plano.id, billing_cycle: "monthly", status: "active" }
    }

    expect(response).to redirect_to(admin_host_path(host))
    expect(flash[:alert]).to include("Assinatura já encerrada.")
    expect(host.reload.subscription.plan).to eq(outro_plano)
  end
end

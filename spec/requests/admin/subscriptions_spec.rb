require "rails_helper"

RSpec.describe "Admin Subscriptions", type: :request do
  let!(:owner) { create(:owner) }
  let!(:host) { create(:host) }
  let!(:plan) { create(:plan, slug: "pro", name: "Pro") }

  before { sign_in_owner owner }

  it "edita assinatura do anfitrião" do
    create(:subscription, host: host, plan: plan)
    patch admin_host_subscription_path(host), params: {
      subscription: { plan_id: plan.id, billing_cycle: "annual", status: "active" }
    }
    expect(response).to redirect_to(admin_host_path(host))
    expect(host.reload.subscription.plan).to eq(plan)
    expect(host.subscription.status).to eq("active")
    expect(host.subscription.billing_cycle).to eq("annual")
  end

  it "calcula MRR corretamente para ciclos diferentes" do
    subscription = create(:subscription, host: host, plan: plan, billing_cycle: "monthly", status: "active")
    expect(subscription.mrr_cents).to eq(plan.monthly_price_cents)

    subscription.update!(billing_cycle: "quarterly")
    expect(subscription.mrr_cents).to eq((plan.quarterly_price_cents / 3.0).round)

    subscription.update!(billing_cycle: "semiannual")
    expect(subscription.mrr_cents).to eq((plan.semiannual_price_cents / 6.0).round)

    subscription.update!(billing_cycle: "annual")
    expect(subscription.mrr_cents).to eq((plan.annual_price_cents / 12.0).round)
  end
end
require "rails_helper"

RSpec.describe Subscription do
  let(:plan) do
    create(:plan, monthly_price_cents: 5000, quarterly_price_cents: 13_500,
                  semiannual_price_cents: 25_500, annual_price_cents: 45_000)
  end

  describe "acesso ao guia" do
    it "libera durante o trial vigente" do
      subscription = build(:subscription, status: :trial, trial_ends_at: 3.days.from_now)

      expect(subscription).to be_grants_access
    end

    it "bloqueia quando o trial expira" do
      subscription = build(:subscription, status: :trial, trial_ends_at: 1.day.ago)

      expect(subscription).not_to be_grants_access
      expect(subscription).to be_trial_expired
    end

    it "libera quando ativa ou inadimplente" do
      expect(build(:subscription, status: :active, trial_ends_at: nil)).to be_grants_access
      expect(build(:subscription, status: :past_due, trial_ends_at: nil)).to be_grants_access
    end

    it "bloqueia quando cancelada ou aguardando pagamento" do
      expect(build(:subscription, status: :canceled, trial_ends_at: nil)).not_to be_grants_access
      expect(build(:subscription, status: :pending, trial_ends_at: nil)).not_to be_grants_access
    end
  end

  describe "preço por ciclo" do
    it "cobra o valor cheio do ciclo escolhido" do
      subscription = build(:subscription, plan: plan, billing_cycle: :annual)

      expect(subscription.price_cents).to eq(45_000)
      expect(subscription.price).to eq(450.0)
    end

    it "normaliza o MRR para base mensal" do
      expect(build(:subscription, plan: plan, billing_cycle: :monthly).mrr_cents).to eq(5000)
      expect(build(:subscription, plan: plan, billing_cycle: :quarterly).mrr_cents).to eq(4500)
      expect(build(:subscription, plan: plan, billing_cycle: :annual).mrr_cents).to eq(3750)
    end
  end

  describe "#renew_period!" do
    it "avança o período conforme o ciclo" do
      subscription = create(:subscription, plan: plan, billing_cycle: :quarterly)
      starts_at = Time.zone.parse("2026-03-10 12:00")

      subscription.renew_period!(starts_at)

      expect(subscription.current_period_start).to eq(starts_at)
      expect(subscription.current_period_end).to eq(starts_at + 3.months)
    end
  end

  it "aceita apenas um responsável válido pelo cancelamento" do
    subscription = create(:subscription)

    subscription.update!(canceled_by: :host)

    expect(subscription).to be_canceled_by_host
    expect { subscription.update!(canceled_by: :ninguem) }.to raise_error(ArgumentError)
  end
end

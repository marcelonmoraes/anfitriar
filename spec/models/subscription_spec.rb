require "rails_helper"

RSpec.describe Subscription do
  describe ".start_trial_for" do
    it "cria trial no plano Pro com a duração configurada" do
      pro = create(:plan, slug: "pro", name: "Pro")
      host = create(:host)

      subscription = described_class.start_trial_for(host)

      expect(subscription.plan).to eq(pro)
      expect(subscription).to be_trial
      expect(subscription.trial_ends_at.to_date).to eq(Date.current + 7)
    end
  end

  it "permite uma única assinatura por anfitrião" do
    subscription = create(:subscription)
    duplicate = build(:subscription, host: subscription.host)
    expect(duplicate).not_to be_valid
  end

  describe "#trial_days_left" do
    it "conta os dias restantes, sem ficar negativo" do
      subscription = create(:subscription, trial_ends_at: 3.days.from_now)
      expect(subscription.trial_days_left).to eq(3)

      expired = create(:subscription, trial_ends_at: 2.days.ago)
      expect(expired.trial_days_left).to eq(0)
    end
  end
end

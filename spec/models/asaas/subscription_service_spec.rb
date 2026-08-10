require "rails_helper"

RSpec.describe Asaas::SubscriptionService do
  let(:host) { create(:host, :with_billing_profile) }
  let(:plan) { create(:plan, name: "Pro", monthly_price_cents: 4990, annual_price_cents: 49_900) }
  let(:credit_card) { create(:credit_card, host: host) }
  let(:subscription) do
    create(:subscription, host: host, plan: plan, billing_cycle: :monthly, status: :trial)
  end

  def service(client)
    described_class.new(client: client, customer_service: Asaas::CustomerService.new(client: client))
  end

  describe "#create" do
    it "cria a assinatura recorrente no cartão e deixa aguardando pagamento" do
      client = fake_asaas_client

      service(client).create(subscription, credit_card, remote_ip: "203.0.113.10")

      expect(subscription.reload).to be_pending
      expect(subscription.asaas_subscription_id).to eq("sub_fake_1")
      expect(subscription.credit_card).to eq(credit_card)
    end

    it "envia ciclo, valor e cartão no formato do Asaas" do
      client = fake_asaas_client
      subscription.update!(billing_cycle: :annual)

      service(client).create(subscription, credit_card, remote_ip: "203.0.113.10")

      payload = client.payload_for(:create_subscription)
      expect(payload[:billingType]).to eq("CREDIT_CARD")
      expect(payload[:cycle]).to eq("ANNUAL")
      expect(payload[:value]).to eq(499.0)
      expect(payload[:creditCardToken]).to eq(credit_card.asaas_token)
      expect(payload[:externalReference]).to eq(subscription.id.to_s)
    end
  end

  describe "#cancel" do
    it "cancela no Asaas e registra quem cancelou" do
      client = fake_asaas_client
      subscription.update!(status: :active, asaas_subscription_id: "sub_1", trial_ends_at: nil)

      service(client).cancel(subscription, canceled_by: :host)

      expect(client).to be_called(:cancel_subscription)
      expect(subscription.reload).to be_canceled
      expect(subscription).to be_canceled_by_host
      expect(subscription.canceled_at).to be_present
    end

    it "cancela localmente mesmo sem assinatura no Asaas" do
      client = fake_asaas_client
      subscription.update!(asaas_subscription_id: nil)

      service(client).cancel(subscription, canceled_by: :admin)

      expect(client).not_to be_called(:cancel_subscription)
      expect(subscription.reload).to be_canceled
    end
  end

  describe "#change_credit_card" do
    it "aponta a assinatura para o novo cartão" do
      client = fake_asaas_client
      subscription.update!(asaas_subscription_id: "sub_1", credit_card: credit_card)
      novo = create(:credit_card, host: host)

      service(client).change_credit_card(subscription, novo, remote_ip: "203.0.113.10")

      expect(subscription.reload.credit_card).to eq(novo)
      expect(client.payload_for(:update_subscription).last[:creditCardToken]).to eq(novo.asaas_token)
    end
  end

  describe "#change_plan" do
    it "atualiza valor e ciclo das cobranças pendentes" do
      client = fake_asaas_client
      subscription.update!(asaas_subscription_id: "sub_1", billing_cycle: :annual)

      service(client).change_plan(subscription)

      payload = client.payload_for(:update_subscription).last
      expect(payload[:cycle]).to eq("ANNUAL")
      expect(payload[:value]).to eq(499.0)
      expect(payload[:updatePendingPayments]).to be(true)
    end
  end
end

require "rails_helper"

RSpec.describe Asaas::WebhookProcessor do
  let(:host) { create(:host) }
  let!(:subscription) do
    create(:subscription, host: host, status: :pending, billing_cycle: :monthly,
                          asaas_subscription_id: "sub_123", trial_ends_at: nil)
  end

  def process(event_type, payload_extra = {})
    event = create(:asaas_webhook_event,
      event_type: event_type,
      payload: { "id" => "evt_x", "event" => event_type }.merge(payload_extra))

    described_class.new(event).process!
    subscription.reload
    event
  end

  describe "pagamento confirmado" do
    it "ativa a assinatura e agenda o período seguinte" do
      process("PAYMENT_CONFIRMED",
        "payment" => { "subscription" => "sub_123", "paymentDate" => "2026-05-10" })

      expect(subscription).to be_active
      expect(subscription.current_period_start.to_date).to eq(Date.new(2026, 5, 10))
      expect(subscription.current_period_end.to_date).to eq(Date.new(2026, 6, 10))
    end

    it "recupera uma assinatura inadimplente" do
      subscription.update!(status: :past_due)

      process("PAYMENT_RECEIVED", "payment" => { "subscription" => "sub_123" })

      expect(subscription).to be_active
    end

    it "vincula o evento à assinatura encontrada" do
      event = process("PAYMENT_CONFIRMED", "payment" => { "subscription" => "sub_123" })

      expect(event.reload.subscription).to eq(subscription)
    end
  end

  describe "pagamento em atraso" do
    it "marca como inadimplente e avisa o anfitrião" do
      expect {
        process("PAYMENT_OVERDUE", "payment" => { "subscription" => "sub_123" })
      }.to have_enqueued_mail(SubscriptionMailer, :payment_overdue)

      expect(subscription).to be_past_due
    end

    it "não avisa duas vezes se já estava inadimplente" do
      subscription.update!(status: :past_due)

      expect {
        process("PAYMENT_OVERDUE", "payment" => { "subscription" => "sub_123" })
      }.not_to have_enqueued_mail(SubscriptionMailer, :payment_overdue)
    end
  end

  describe "cancelamento" do
    it "cancela quando a assinatura é removida no Asaas" do
      expect {
        process("SUBSCRIPTION_DELETED", "subscription" => { "id" => "sub_123" })
      }.to have_enqueued_mail(SubscriptionMailer, :canceled)

      expect(subscription).to be_canceled
      expect(subscription.canceled_at).to be_present
      expect(subscription).to be_canceled_by_system
    end

    it "cancela quando a assinatura fica inativa" do
      process("SUBSCRIPTION_UPDATED", "subscription" => { "id" => "sub_123", "status" => "INACTIVE" })

      expect(subscription).to be_canceled
    end

    it "ignora atualização que mantém a assinatura ativa" do
      subscription.update!(status: :active)

      process("SUBSCRIPTION_UPDATED", "subscription" => { "id" => "sub_123", "status" => "ACTIVE" })

      expect(subscription).to be_active
    end
  end

  it "ignora eventos desconhecidos sem levantar erro" do
    expect { process("PAYMENT_ANTICIPATED", "payment" => { "subscription" => "sub_123" }) }
      .not_to raise_error
  end

  it "ignora eventos de assinaturas que não conhecemos" do
    expect { process("PAYMENT_CONFIRMED", "payment" => { "subscription" => "sub_desconhecida" }) }
      .not_to change { subscription.reload.status }
  end
end

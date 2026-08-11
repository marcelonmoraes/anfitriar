require "rails_helper"

RSpec.describe Asaas::WebhookJob do
  let!(:subscription) do
    create(:subscription, status: :pending, asaas_subscription_id: "sub_123", trial_ends_at: nil)
  end

  let(:event) do
    create(:asaas_webhook_event,
      event_type: "PAYMENT_CONFIRMED",
      payload: { "id" => "evt_1", "event" => "PAYMENT_CONFIRMED",
                 "payment" => { "subscription" => "sub_123" } })
  end

  it "processa o evento e o marca como concluído" do
    described_class.perform_now(event.id)

    expect(event.reload).to be_processed
    expect(event).not_to be_failed
    expect(subscription.reload).to be_active
  end

  it "não processa duas vezes o mesmo evento" do
    described_class.perform_now(event.id)
    subscription.update!(status: :past_due)

    described_class.perform_now(event.id)

    expect(subscription.reload).to be_past_due
  end

  it "registra o erro e reagenda a tentativa" do
    allow_any_instance_of(Asaas::WebhookProcessor).to receive(:process!).and_raise("Falha do Asaas")

    expect { described_class.perform_now(event.id) }.to have_enqueued_job(described_class)

    expect(event.reload).to be_failed
    expect(event).not_to be_processed
    expect(event.error_message).to eq("Falha do Asaas")
  end

  it "descarta o job quando o evento não existe mais" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end

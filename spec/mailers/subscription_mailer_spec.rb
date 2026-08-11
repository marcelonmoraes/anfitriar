require "rails_helper"

RSpec.describe SubscriptionMailer do
  let(:host) { create(:host, email_address: "ana@example.com", name: "Ana") }
  let(:plan) { create(:plan, name: "Pro") }
  let(:subscription) do
    create(:subscription, host: host, plan: plan, status: :active,
                          current_period_end: Date.new(2026, 9, 1), trial_ends_at: nil)
  end

  it "confirma o pagamento informando a próxima cobrança" do
    mail = described_class.payment_confirmed(subscription)

    expect(mail.to).to eq([ "ana@example.com" ])
    expect(mail.subject).to eq("Pagamento confirmado — plano Pro")
    expect(mail.body.encoded).to include("Ana")
  end

  it "avisa sobre a cobrança recusada apontando para os cartões" do
    mail = described_class.payment_overdue(subscription)

    expect(mail.subject).to eq("Não conseguimos processar seu pagamento")
    expect(mail.body.encoded).to include("credit_cards")
  end

  it "informa o cancelamento com opção de reativar" do
    mail = described_class.canceled(subscription)

    expect(mail.subject).to eq("Sua assinatura foi cancelada")
    expect(mail.body.encoded).to include("subscription")
  end
end

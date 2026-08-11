require "rails_helper"

RSpec.describe Asaas::CreditCardService do
  let(:host) { create(:host, :with_billing_profile) }
  let(:card) do
    CreditCardForm.new(holder_name: "ANA ANFITRIA", number: "4242424242424242",
                       expiry: "03/#{(Date.current.year + 2).to_s.last(2)}", cvv: "123")
  end

  it "cria o customer, tokeniza e guarda apenas dados não sensíveis" do
    client = fake_asaas_client

    credit_card = described_class.new(client: client, customer_service: Asaas::CustomerService.new(client: client))
                                 .tokenize(host: host, card: card, remote_ip: "203.0.113.10")

    expect(credit_card.asaas_token).to eq("tok_fake_1")
    expect(credit_card.brand).to eq("VISA")
    expect(credit_card.last_four).to eq("4242")
    expect(host.reload.asaas_customer_id).to eq("cus_fake_1")
  end

  it "envia o cartão ao Asaas no formato esperado" do
    client = fake_asaas_client

    described_class.new(client: client, customer_service: Asaas::CustomerService.new(client: client))
                   .tokenize(host: host, card: card, remote_ip: "203.0.113.10")

    payload = client.payload_for(:tokenize_credit_card)
    expect(payload[:creditCard][:expiryMonth]).to eq("03")
    expect(payload[:creditCard][:expiryYear]).to eq((Date.current.year + 2).to_s)
    expect(payload[:remoteIp]).to eq("203.0.113.10")
    expect(payload[:creditCardHolderInfo][:cpfCnpj]).to eq(host.cpf_cnpj)
  end

  it "não persiste o número nem o cvv do cartão" do
    client = fake_asaas_client

    credit_card = described_class.new(client: client, customer_service: Asaas::CustomerService.new(client: client))
                                 .tokenize(host: host, card: card, remote_ip: "203.0.113.10")

    expect(credit_card.attributes.values.map(&:to_s)).not_to include("4242424242424242", "123")
  end

  it "exige os dados de cobrança do anfitrião" do
    client = fake_asaas_client
    incomplete = create(:host)

    expect {
      described_class.new(client: client, customer_service: Asaas::CustomerService.new(client: client))
                     .tokenize(host: incomplete, card: card, remote_ip: "203.0.113.10")
    }.to raise_error(described_class::MissingBillingProfile)
  end

  it "desativa as notificações do Asaas ao criar o customer" do
    client = fake_asaas_client

    described_class.new(client: client, customer_service: Asaas::CustomerService.new(client: client))
                   .tokenize(host: host, card: card, remote_ip: "203.0.113.10")

    expect(client.payload_for(:create_customer)[:notificationDisabled]).to be(true)
  end
end

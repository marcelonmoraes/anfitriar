require "rails_helper"

RSpec.describe CreditCard do
  let(:host) { create(:host) }

  it "torna o primeiro cartão padrão automaticamente" do
    card = create(:credit_card, host: host)

    expect(card.reload).to be_default
  end

  it "não torna padrão os cartões seguintes" do
    create(:credit_card, host: host)
    second = create(:credit_card, host: host)

    expect(second.reload).not_to be_default
  end

  it "troca o cartão padrão de forma exclusiva" do
    first = create(:credit_card, host: host)
    second = create(:credit_card, host: host)

    second.make_default!

    expect(second.reload).to be_default
    expect(first.reload).not_to be_default
  end

  it "lista o cartão padrão primeiro" do
    create(:credit_card, host: host)
    second = create(:credit_card, host: host)
    second.make_default!

    expect(host.credit_cards.default_first.first).to eq(second)
  end

  it "reconhece cartão vencido" do
    expect(build(:credit_card, :expired)).to be_expired
    expect(build(:credit_card)).not_to be_expired
  end

  it "formata a validade e a identificação" do
    card = build(:credit_card, brand: "VISA", last_four: "4242", expiry_month: 3, expiry_year: 2031)

    expect(card.expires_on).to eq("03/31")
    expect(card.to_s).to eq("VISA •••• 4242")
  end

  it "impede o mesmo token duas vezes para o mesmo anfitrião" do
    create(:credit_card, host: host, asaas_token: "tok_1")
    duplicate = build(:credit_card, host: host, asaas_token: "tok_1")

    expect(duplicate).to be_invalid
  end
end

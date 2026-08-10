require "rails_helper"

RSpec.describe CreditCardForm do
  def build_form(**overrides)
    described_class.new(
      { holder_name: "ANA ANFITRIA", number: "4242 4242 4242 4242",
        expiry: "12/#{(Date.current.year + 2).to_s.last(2)}", cvv: "123" }.merge(overrides)
    )
  end

  it "aceita um cartão válido" do
    expect(build_form).to be_valid
  end

  it "normaliza número, cvv e documento removendo máscara" do
    form = build_form(number: "4242-4242 4242.4242", cvv: "1a2b3", document: "529.982.247-25")

    expect(form.number).to eq("4242424242424242")
    expect(form.cvv).to eq("123")
    expect(form.document).to eq("52998224725")
  end

  it "rejeita número que falha no dígito verificador" do
    form = build_form(number: "4242424242424241")

    expect(form).to be_invalid
    expect(form.errors[:number]).to include("é inválido")
  end

  it "rejeita número curto demais" do
    form = build_form(number: "424242")

    expect(form).to be_invalid
    expect(form.errors[:number]).to include("deve ter entre 13 e 19 dígitos")
  end

  it "rejeita cartão vencido" do
    form = build_form(expiry: "01/20")

    expect(form).to be_invalid
    expect(form.errors[:expiry]).to include("está vencida")
  end

  it "rejeita mês inválido" do
    form = build_form(expiry: "13/30")

    expect(form).to be_invalid
    expect(form.errors[:expiry]).to include("tem mês inválido")
  end

  it "rejeita validade sem o formato MM/AA" do
    form = build_form(expiry: "1230")

    expect(form).to be_invalid
    expect(form.errors[:expiry]).to include("deve estar no formato MM/AA")
  end

  it "rejeita cvv fora de 3 ou 4 dígitos" do
    expect(build_form(cvv: "12")).to be_invalid
    expect(build_form(cvv: "12345")).to be_invalid
  end

  it "interpreta mês e ano da validade" do
    form = build_form(expiry: "07/29")

    expect(form.expiry_month).to eq(7)
    expect(form.expiry_year).to eq(2029)
  end

  it "nunca expõe o número completo ao ser inspecionado" do
    form = build_form

    expect(form.inspect).not_to include("4242424242424242")
    expect(form.inspect).to include("4242")
  end
end

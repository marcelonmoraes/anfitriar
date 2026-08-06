require "rails_helper"

RSpec.describe Host do
  it "normaliza o e-mail" do
    host = create(:host, email_address: "  Ana@Example.COM ")
    expect(host.email_address).to eq("ana@example.com")
  end

  it "normaliza o telefone para dígitos" do
    host = create(:host, phone: "(11) 98765-4321")
    expect(host.phone).to eq("11987654321")
  end

  it "exige e-mail único" do
    create(:host, email_address: "ana@example.com")
    expect(build(:host, email_address: "ana@example.com")).not_to be_valid
  end

  it "exige nome, telefone e senha" do
    host = described_class.new
    host.valid?
    expect(host.errors[:name]).to be_present
    expect(host.errors[:phone]).to be_present
    expect(host.errors[:password]).to be_present
  end

  it "rejeita telefone sem DDD" do
    expect(build(:host, phone: "987654321")).not_to be_valid
  end

  it "autentica por senha" do
    host = create(:host, password: "senha-segura-123")
    expect(host.authenticate("senha-segura-123")).to eq(host)
    expect(host.authenticate("errada")).to be_falsey
  end
end

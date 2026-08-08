require "rails_helper"

RSpec.describe Owner do
  it "normaliza o e-mail" do
    owner = create(:owner, email_address: "  Admin@Anfitriar.COM ")
    expect(owner.email_address).to eq("admin@anfitriar.com")
  end

  it "exige e-mail único" do
    create(:owner, email_address: "admin@anfitriar.com")
    expect(build(:owner, email_address: "admin@anfitriar.com")).not_to be_valid
  end

  it "exige nome e senha" do
    owner = described_class.new
    owner.valid?
    expect(owner.errors[:name]).to be_present
    expect(owner.errors[:password]).to be_present
  end

  it "autentica por senha" do
    owner = create(:owner, password: "senha-admin-123")
    expect(owner.authenticate("senha-admin-123")).to eq(owner)
    expect(owner.authenticate("errada")).to be_falsey
  end
end
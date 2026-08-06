require "rails_helper"

RSpec.describe Property do
  it "exige nome e endereço" do
    property = described_class.new(host: create(:host))
    property.valid?
    expect(property.errors[:name]).to be_present
    expect(property.errors[:address]).to be_present
  end

  describe "limite do plano" do
    it "bloqueia criação acima do max_properties do plano" do
      host = create(:host)
      create(:subscription, host: host, plan: create(:plan, :limited))
      create(:property, host: host)

      second = build(:property, host: host)
      expect(second).not_to be_valid
      expect(second.errors[:base].join).to include("limite")
    end

    it "não limita quando o plano é ilimitado" do
      host = create(:host)
      create(:subscription, host: host, plan: create(:plan, max_properties: nil))
      create(:property, host: host)
      expect(build(:property, host: host)).to be_valid
    end

    it "não limita edição de hospedagem existente" do
      host = create(:host)
      property = create(:property, host: host)
      create(:subscription, host: host, plan: create(:plan, :limited))
      property.name = "Novo nome"
      expect(property).to be_valid
    end
  end
end

require "rails_helper"

RSpec.describe Plan do
  it "exige slug e nome únicos" do
    create(:plan, slug: "essencial", name: "Essencial")
    duplicate = build(:plan, slug: "essencial", name: "Essencial")
    expect(duplicate).not_to be_valid
  end

  it "rejeita preços negativos" do
    plan = build(:plan, monthly_price_cents: -1)
    expect(plan).not_to be_valid
  end

  it "aceita max_properties nulo (ilimitado)" do
    expect(build(:plan, max_properties: nil)).to be_valid
  end

  describe "seeds" do
    it "cria Essencial e Pro com os valores da spec, de forma idempotente" do
      2.times { Rails.application.load_seed }

      expect(Plan.count).to eq(2)

      essencial = Plan.find_by!(slug: "essencial")
      expect(essencial.max_properties).to eq(3)
      expect(essencial.monthly_price_cents).to eq(1990)
      expect(essencial.quarterly_price_cents).to eq(5373)
      expect(essencial.semiannual_price_cents).to eq(10_149)
      expect(essencial.annual_price_cents).to eq(17_910)

      pro = Plan.find_by!(slug: "pro")
      expect(pro.max_properties).to be_nil
      expect(pro.monthly_price_cents).to eq(3990)
      expect(pro.quarterly_price_cents).to eq(10_773)
      expect(pro.semiannual_price_cents).to eq(20_349)
      expect(pro.annual_price_cents).to eq(35_910)
    end
  end
end

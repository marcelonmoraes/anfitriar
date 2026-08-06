require "rails_helper"

RSpec.describe Card do
  it "é único por hospedagem + categoria" do
    card = create(:card)
    duplicate = build(:card, property: card.property, category: card.category)
    expect(duplicate).not_to be_valid
  end

  describe "#filled?" do
    it "é verdadeiro só com descrição presente" do
      expect(build(:card, description: "<p>Wi-Fi: casa123</p>")).to be_filled
      expect(build(:card, description: nil)).not_to be_filled
    end
  end

  describe ".upsert_for" do
    it "cria o card na primeira escrita e atualiza depois, sem duplicar" do
      property = create(:property)
      category = create(:category, position: 1)

      expect {
        described_class.upsert_for(property, category, description: "<p>v1</p>")
      }.to change(described_class, :count).by(1)

      expect {
        described_class.upsert_for(property, category, description: "<p>v2</p>")
      }.not_to change(described_class, :count)

      expect(property.cards.sole.description.to_plain_text).to eq("v2")
    end

    it "atualiza só o que foi passado, preservando o resto" do
      property = create(:property)
      category = create(:category, position: 1)
      described_class.upsert_for(property, category, description: "<p>conteúdo</p>")

      card = described_class.upsert_for(property, category, hidden: true)
      expect(card).to be_hidden
      expect(card.description.to_plain_text).to eq("conteúdo")
    end
  end

  it "morre junto com a categoria própria" do
    host = create(:host)
    category = create(:category, :own, host: host)
    property = create(:property, host: host)
    create(:card, property: property, category: category)

    expect { category.destroy }.to change(described_class, :count).by(-1)
  end
end

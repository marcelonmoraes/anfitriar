require "rails_helper"

RSpec.describe Property, "guia" do
  let(:host) { create(:host) }
  let(:property) { create(:property, host: host) }
  let!(:wifi) { create(:category, name: "Wi-Fi", position: 1) }
  let!(:rules) { create(:category, name: "Regras da casa", position: 2) }
  let!(:own) { create(:category, :own, host: host, name: "Minha adega") }

  describe "#guide_entries" do
    it "põe cards existentes em ordem de posição e categorias sem card ao final" do
      rules_card = create(:card, property: property, category: rules, position: 1)

      entries = property.guide_entries
      expect(entries.first).to eq([ rules, rules_card ])
      expect(entries.map(&:first)).to eq([ rules, wifi, own ])
      expect(entries.last(2).map(&:last)).to eq([ nil, nil ])
    end

    it "ignora categorias próprias de outros anfitriões" do
      create(:category, :own, name: "De outro")
      expect(property.guide_entries.map { |category, _| category.name }).not_to include("De outro")
    end
  end

  describe "#guide_progress" do
    it "conta cards preenchidos sobre o total de categorias disponíveis" do
      create(:card, property: property, category: wifi, description: "<p>senha</p>")
      create(:card, property: property, category: rules, description: nil)

      expect(property.guide_progress).to eq(filled: 1, total: 3)
    end
  end

  describe "#visible_cards" do
    it "exclui ocultos e vazios, mantendo a ordem" do
      visible = create(:card, property: property, category: rules, position: 1)
      create(:card, property: property, category: wifi, position: 2, hidden: true)
      create(:card, property: property, category: own, position: 3, description: nil)

      expect(property.visible_cards).to eq([ visible ])
    end
  end
end

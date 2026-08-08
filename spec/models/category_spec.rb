require "rails_helper"

RSpec.describe Category do
  it "distingue categorias padrão de próprias" do
    expect(build(:category)).to be_standard
    expect(build(:category, :own)).not_to be_standard
  end

  it "exige nome único dentro do mesmo dono" do
    create(:category, name: "Wi-Fi")
    expect(build(:category, name: "Wi-Fi")).not_to be_valid

    host = create(:host)
    create(:category, :own, host: host, name: "Minha praia")
    expect(build(:category, :own, host: host, name: "Minha praia")).not_to be_valid
  end

  it "permite que uma categoria própria repita o nome de uma padrão" do
    create(:category, name: "Wi-Fi")
    host = create(:host)
    expect(build(:category, :own, host: host, name: "Wi-Fi")).to be_valid
  end

  describe ".available_to" do
    it "lista padrão em ordem de posição e depois as próprias do anfitrião" do
      second = create(:category, name: "B-padrão", position: 2)
      first = create(:category, name: "A-padrão", position: 1)
      host = create(:host)
      own = create(:category, :own, host: host, name: "Minha categoria")
      create(:category, :own, name: "De outro anfitrião")

      expect(described_class.available_to(host)).to eq([ first, second, own ])
    end
  end

  describe "seeds" do
    it "cria as 11 categorias padrão de forma idempotente" do
      2.times { Rails.application.load_seed }
      expect(Category.standard.count).to eq(11)
      expect(Category.standard.ordered.first.name).to eq("Wi-Fi")
      expect(Category.standard.ordered.last.name).to eq("Transporte")
    end
  end
end

require "rails_helper"

RSpec.describe "Montar o guia", type: :request do
  let!(:host) { create(:host) }
  let!(:property) { create(:property, host: host) }
  let!(:wifi) { create(:category, name: "Wi-Fi", position: 1) }
  let!(:rules) { create(:category, name: "Regras da casa", position: 2) }

  before { sign_in host }

  it "mostra todas as categorias e o progresso" do
    get property_guide_path(property)
    expect(response.body).to include("Wi-Fi")
    expect(response.body).to include("Regras da casa")
    expect(response.body).to include("0 de 2")
  end

  it "salva a descrição de um card (upsert)" do
    patch property_guide_card_path(property, category_id: wifi.id),
          params: { card: { description: "<p>Rede: Casa / Senha: 12345</p>" } }

    expect(response).to redirect_to(property_guide_path(property))
    card = property.cards.sole
    expect(card.category).to eq(wifi)
    expect(card.description.to_plain_text).to include("Casa")
  end

  it "oculta e mostra um card sem apagar a descrição" do
    Card.upsert_for(property, wifi, description: "<p>senha</p>")

    patch property_guide_card_path(property, category_id: wifi.id), params: { card: { hidden: "1" } }
    card = property.cards.sole
    expect(card).to be_hidden
    expect(card.description).to be_present
  end

  it "reordena via lista de category_ids" do
    patch property_guide_reorder_path(property),
          params: { category_ids: [ rules.id.to_s, wifi.id.to_s ] }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(property.guide_entries.map(&:first)).to eq([ rules, wifi ])
  end

  it "rejeita categoria de outro anfitrião no guia (404)" do
    foreign = create(:category, :own)
    patch property_guide_card_path(property, category_id: foreign.id),
          params: { card: { description: "<p>x</p>" } }
    expect(response).to have_http_status(:not_found)
  end

  it "rejeita hospedagem de outro anfitrião (404)" do
    other_property = create(:property)
    get property_guide_path(other_property)
    expect(response).to have_http_status(:not_found)
  end
end

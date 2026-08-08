require "rails_helper"

RSpec.describe "Admin Categories", type: :request do
  let!(:owner) { create(:owner) }

  before { sign_in_owner owner }

  it "lista apenas categorias padrão do sistema" do
    create(:category, name: "Categoria Padrão", host: nil)
    host = create(:host)
    create(:category, name: "Categoria Própria", host: host)

    get admin_categories_path
    expect(response.body).to include("Categoria Padrão")
    expect(response.body).not_to include("Categoria Própria")
  end

  it "cria nova categoria padrão" do
    expect {
      post admin_categories_path, params: { category: { name: "Estacionamento", position: 12 } }
    }.to change(Category.standard, :count).by(1)

    expect(response).to redirect_to(admin_categories_path)
  end

  it "edita categoria padrão" do
    cat = create(:category, name: "Antigo", host: nil)
    patch admin_category_path(cat), params: { category: { name: "Novo Nome" } }
    expect(response).to redirect_to(admin_categories_path)
    expect(cat.reload.name).to eq("Novo Nome")
  end
end
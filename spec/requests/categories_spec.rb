require "rails_helper"

RSpec.describe "Categorias", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "lista categorias padrão como referência e as próprias com ações" do
    create(:category, name: "Wi-Fi", position: 1)
    create(:category, :own, host: host, name: "Minha adega")

    get categories_path
    expect(response.body).to include("Wi-Fi")
    expect(response.body).to include("Minha adega")
  end

  it "cria categoria própria" do
    expect {
      post categories_path, params: { category: { name: "Passeios de barco" } }
    }.to change(host.categories, :count).by(1)
  end

  it "não permite editar nem excluir categoria padrão (404)" do
    standard = create(:category, name: "Wi-Fi", position: 1)

    get edit_category_path(standard)
    expect(response).to have_http_status(:not_found)

    delete category_path(standard)
    expect(response).to have_http_status(:not_found)
    expect(Category.exists?(standard.id)).to be true
  end

  it "não permite mexer em categoria própria de outro anfitrião (404)" do
    other = create(:category, :own)
    delete category_path(other)
    expect(response).to have_http_status(:not_found)
  end

  it "exclui categoria própria" do
    category = create(:category, :own, host: host)
    expect { delete category_path(category) }.to change(host.categories, :count).by(-1)
  end
end

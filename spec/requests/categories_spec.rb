require "rails_helper"

RSpec.describe "Categorias", type: :request do
  let!(:host) { create(:host) }

  before { sign_in host }

  it "lista categorias padrão como referência e as próprias com ações" do
    standard = create(:category, name: "Wi-Fi", position: 1)
    own = create(:category, :own, host: host, name: "Minha adega")

    get categories_path
    expect(response.body).to include("Wi-Fi")
    expect(response.body).to include("Minha adega")
    expect(response.body).not_to include(edit_category_path(standard))
    expect(response.body).not_to include("action=\"#{category_path(standard)}\"")
    expect(response.body).to include(edit_category_path(own))
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

  it "edita e atualiza categoria própria" do
    category = create(:category, :own, host: host, name: "Antiga")

    get edit_category_path(category)
    expect(response).to have_http_status(:ok)

    patch category_path(category), params: { category: { name: "Nova" } }
    expect(response).to redirect_to(categories_path)
    expect(category.reload.name).to eq("Nova")
  end

  it "reexibe o formulário quando inválido" do
    category = create(:category, :own, host: host, name: "Válida")

    post categories_path, params: { category: { name: "" } }
    expect(response).to have_http_status(:unprocessable_content)

    patch category_path(category), params: { category: { name: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(category.reload.name).to eq("Válida")
  end
end

require "rails_helper"

RSpec.describe "Edição do guia", type: :system do
  it "navega da hospedagem para o guia e vê categorias e progresso" do
    host = create(:host, password: "senha-segura-123")
    property = create(:property, host: host, name: "Chalé da Serra")
    create(:category, name: "Wi-Fi", position: 1)
    Card.upsert_for(property, Category.first, description: "<p>Rede: Chalé</p>")

    visit new_session_path
    fill_in "E-mail", with: host.email_address
    fill_in "Senha", with: "senha-segura-123"
    click_button "Entrar"

    click_link "Chalé da Serra"
    click_link "Montar o guia"

    expect(page).to have_content("Wi-Fi")
    expect(page).to have_content("1 de 1")
  end
end

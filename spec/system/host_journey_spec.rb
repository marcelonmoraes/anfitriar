require "rails_helper"

RSpec.describe "Jornada do anfitrião", type: :system do
  before do
    create(:plan, slug: "pro", name: "Pro")
    create(:category, name: "Wi-Fi", position: 1)
  end

  it "cadastra, cria hospedagem, cliente e reserva com link" do
    visit new_registration_path
    fill_in "Nome", with: "Ana Anfitriã"
    fill_in "E-mail", with: "ana@example.com"
    fill_in "Telefone", with: "11987654321"
    fill_in "Senha", with: "senha-segura-123"
    fill_in "Confirmação de senha", with: "senha-segura-123"
    click_button "Criar conta"
    expect(page).to have_content("período de teste")

    click_link "Nova hospedagem"
    fill_in "Nome", with: "Chalé da Serra"
    fill_in "Endereço", with: "Estrada da Serra, 42"
    click_button "Criar Hospedagem"
    expect(page).to have_content("Hospedagem criada")

    click_link "Clientes"
    click_link "Novo cliente"
    fill_in "Nome", with: "Carlos Hóspede"
    fill_in "CPF", with: "390.533.447-05"
    fill_in "Telefone", with: "(11) 91234-5678"
    click_button "Criar Cliente"
    expect(page).to have_content("Cliente cadastrado")

    click_link "Reservas"
    click_link "Nova reserva"
    select "Chalé da Serra", from: "Hospedagem"
    select "Carlos Hóspede", from: "Cliente"
    fill_in "Check-in", with: Date.current
    fill_in "Check-out", with: Date.current + 3
    click_button "Criar reserva"

    expect(page).to have_content("Reserva criada")
    expect(page).to have_content("/g/#{Booking.last.access_token}")
  end
end

require "rails_helper"

RSpec.describe "Criação de reserva", type: :system do
  it "cria a reserva e exibe o link para envio" do
    host = create(:host, password: "senha-segura-123")
    create(:property, host: host, name: "Chalé da Serra")
    create(:guest, host: host, name: "Carlos Hóspede")

    visit new_session_path
    fill_in "E-mail", with: host.email_address
    fill_in "Senha", with: "senha-segura-123"
    click_button "Entrar"

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

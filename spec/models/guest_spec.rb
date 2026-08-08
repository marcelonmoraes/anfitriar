require "rails_helper"

RSpec.describe Guest do
  it "normaliza CPF e telefone para dígitos" do
    guest = create(:guest, cpf: "390.533.447-05", phone: "(11) 91234-5678")
    expect(guest.cpf).to eq("39053344705")
    expect(guest.phone).to eq("11912345678")
  end

  it "rejeita CPF inválido" do
    expect(build(:guest, cpf: "11111111111")).not_to be_valid
  end

  it "exige CPF único por anfitrião, mas permite repetir entre anfitriões" do
    guest = create(:guest, cpf: "39053344705")
    expect(build(:guest, host: guest.host, cpf: "390.533.447-05")).not_to be_valid
    expect(build(:guest, cpf: "39053344705")).to be_valid
  end

  it "criptografa CPF e telefone no banco" do
    guest = create(:guest, cpf: "39053344705", phone: "11912345678")
    expect(guest.ciphertext_for(:cpf)).not_to include("39053344705")
    expect(guest.ciphertext_for(:phone)).not_to include("11912345678")
  end

  it "mascara o CPF na exibição" do
    guest = create(:guest, cpf: "39053344705")
    expect(guest.masked_cpf).to eq("***.533.447-**")
  end

  it "expõe os últimos dígitos do telefone" do
    guest = create(:guest, phone: "11912345678")
    expect(guest.phone_last_digits).to eq("5678")
  end

  it "aceita e-mail em branco, rejeita e-mail malformado" do
    expect(build(:guest, email: "")).to be_valid
    expect(build(:guest, email: "invalido")).not_to be_valid
  end
end

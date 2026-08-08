require "rails_helper"

RSpec.describe "Configuração da plataforma" do
  it "usa pt-BR como locale padrão" do
    expect(I18n.default_locale).to eq(:"pt-BR")
  end

  it "usa o fuso de São Paulo" do
    expect(Rails.application.config.time_zone).to eq("America/Sao_Paulo")
  end

  it "filtra PII e tokens dos logs" do
    filters = Rails.application.config.filter_parameters
    %i[cpf phone token access_token].each do |key|
      expect(filters).to include(key), "esperava #{key} nos filter_parameters"
    end
  end
end

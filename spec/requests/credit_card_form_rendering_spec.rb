require "rails_helper"

RSpec.describe "Formulário de cartão", type: :request do
  let!(:host) { create(:host, :with_billing_profile) }
  let!(:plan) { create(:plan, slug: "pro") }

  before { sign_in host }

  shared_examples "formulário traduzido e bem formado" do
    it "traduz todos os rótulos e placeholders" do
      expect(response.body).not_to include("translation_missing")
      expect(response.body).not_to include("Translation missing")

      expect(response.body).to include("Nome impresso no cartão")
      expect(response.body).to include("Número do cartão")
      expect(response.body).to include("Validade")
      expect(response.body).to include("CPF/CNPJ do titular")
      expect(response.body).to include("MM/AA")
    end

    it "mantém as divs balanceadas" do
      body = response.body
      expect(body.scan("<div").size).to eq(body.scan("</div>").size)
    end
  end

  describe "GET /account/credit_cards" do
    before { get account_credit_cards_path }

    include_examples "formulário traduzido e bem formado"
  end

  describe "GET /account/subscription/new" do
    context "sem cartões salvos" do
      before { get new_account_subscription_path }

      include_examples "formulário traduzido e bem formado"
    end

    context "com cartão salvo" do
      before do
        create(:credit_card, host: host)
        get new_account_subscription_path
      end

      include_examples "formulário traduzido e bem formado"

      it "oferece escolher entre o cartão salvo e um novo" do
        expect(response.body).to include("Usar um novo cartão")
      end
    end
  end
end

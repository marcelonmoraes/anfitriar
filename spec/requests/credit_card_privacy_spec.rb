require "rails_helper"

RSpec.describe "Privacidade dos dados de cartão", type: :request do
  let!(:host) { create(:host, :with_billing_profile) }

  it "filtra número, cvv e validade dos parâmetros registrados em log" do
    filtered = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter("credit_card" => { "number" => "4242424242424242", "cvv" => "123", "expiry" => "12/30" })

    expect(filtered["credit_card"].values).to all(eq("[FILTERED]"))
  end

  it "não guarda o número do cartão no banco" do
    fake_asaas_client
    sign_in host

    post account_credit_cards_path, params: {
      credit_card: { holder_name: "ANA ANFITRIA", number: "4242 4242 4242 4242",
                     expiry: "12/#{(Date.current.year + 2).to_s.last(2)}", cvv: "123" }
    }

    stored = CreditCard.last.attributes.values.map(&:to_s).join(" ")
    expect(stored).not_to include("4242424242424242")
    expect(stored).not_to include("123")
  end
end

require "rails_helper"

RSpec.describe "Assinatura do anfitrião", type: :request do
  let!(:host) { create(:host, :with_billing_profile) }
  let!(:plan) { create(:plan, slug: "pro", name: "Pro", monthly_price_cents: 4990) }

  let(:card_params) do
    { holder_name: "ANA ANFITRIA", number: "4242 4242 4242 4242",
      expiry: "12/#{(Date.current.year + 2).to_s.last(2)}", cvv: "123" }
  end

  before { sign_in host }

  describe "GET /account/subscription" do
    it "mostra o convite para assinar quando não há assinatura" do
      get account_subscription_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ver planos")
    end

    it "avisa quando o teste expirou" do
      create(:subscription, host: host, plan: plan, status: :trial, trial_ends_at: 1.day.ago)

      get account_subscription_path

      expect(response.body).to include("Seu período de teste terminou")
    end
  end

  describe "POST /account/subscription" do
    before { create(:subscription, host: host, plan: plan, status: :trial) }

    it "assina com um cartão novo" do
      client = fake_asaas_client

      post account_subscription_path, params: {
        subscription: { plan_id: plan.id, billing_cycle: "monthly" },
        credit_card: card_params
      }

      expect(response).to redirect_to(account_subscription_path)
      expect(host.reload.subscription).to be_pending
      expect(host.credit_cards.count).to eq(1)
      expect(client).to be_called(:create_subscription)
    end

    it "reaproveita um cartão já salvo sem tokenizar de novo" do
      client = fake_asaas_client
      credit_card = create(:credit_card, host: host)

      post account_subscription_path, params: {
        subscription: { plan_id: plan.id, billing_cycle: "annual" },
        credit_card_id: credit_card.id
      }

      expect(response).to redirect_to(account_subscription_path)
      expect(client).not_to be_called(:tokenize_credit_card)
      expect(host.reload.subscription.credit_card).to eq(credit_card)
    end

    it "recusa cartão com número curto demais sem chamar o Asaas" do
      client = fake_asaas_client

      post account_subscription_path, params: {
        subscription: { plan_id: plan.id, billing_cycle: "monthly" },
        credit_card: card_params.merge(number: "4242")
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(client).not_to be_called(:tokenize_credit_card)
      expect(host.reload.subscription).to be_trial
    end

    it "exige os dados de cobrança antes de assinar" do
      fake_asaas_client
      host.update!(cpf_cnpj: nil, postal_code: nil, address_number: nil)

      post account_subscription_path, params: {
        subscription: { plan_id: plan.id, billing_cycle: "monthly" },
        credit_card: card_params
      }

      expect(response).to redirect_to(account_path)
    end

    it "mostra a mensagem do Asaas quando a operadora recusa" do
      client = fake_asaas_client(
        tokenize_error: Asaas::Client::InvalidRequestError.new("Cartão recusado pela operadora.")
      )

      post account_subscription_path, params: {
        subscription: { plan_id: plan.id, billing_cycle: "monthly" },
        credit_card: card_params
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Cartão recusado pela operadora.")
      expect(client).not_to be_called(:create_subscription)
    end
  end

  describe "PATCH /account/subscription" do
    it "muda o plano da assinatura ativa" do
      client = fake_asaas_client
      outro = create(:plan, name: "Max", monthly_price_cents: 9990)
      create(:subscription, host: host, plan: plan, status: :active,
                            billing_cycle: :monthly, asaas_subscription_id: "sub_1", trial_ends_at: nil)

      patch account_subscription_path, params: {
        subscription: { plan_id: outro.id, billing_cycle: "annual" }
      }

      expect(response).to redirect_to(account_subscription_path)
      expect(host.reload.subscription.plan).to eq(outro)
      expect(client).to be_called(:update_subscription)
    end
  end

  describe "DELETE /account/subscription" do
    it "cancela a assinatura registrando o anfitrião como responsável" do
      client = fake_asaas_client
      create(:subscription, host: host, plan: plan, status: :active,
                            asaas_subscription_id: "sub_1", trial_ends_at: nil)

      delete account_subscription_path

      expect(response).to redirect_to(account_subscription_path)
      expect(host.reload.subscription).to be_canceled
      expect(host.subscription).to be_canceled_by_host
      expect(client).to be_called(:cancel_subscription)
    end
  end

  it "exige autenticação" do
    delete session_path
    get account_subscription_path

    expect(response).to redirect_to(new_session_path)
  end
end

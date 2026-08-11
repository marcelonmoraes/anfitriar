require "rails_helper"

RSpec.describe "Webhook do Asaas", type: :request do
  let!(:subscription) do
    create(:subscription, status: :pending, asaas_subscription_id: "sub_123", trial_ends_at: nil)
  end

  let(:secret) { "segredo-do-webhook" }

  let(:payload) do
    {
      id: "evt_1",
      event: "PAYMENT_CONFIRMED",
      payment: { subscription: "sub_123", paymentDate: Date.current.to_s }
    }
  end

  before { allow(Asaas::Configuration).to receive(:webhook_secret).and_return(secret) }

  def post_webhook(body: payload, token: secret)
    post webhooks_asaas_path,
         params: body.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "asaas-access-token" => token }.compact
  end

  it "aceita o evento e enfileira o processamento" do
    expect { post_webhook }.to have_enqueued_job(Asaas::WebhookJob)

    expect(response).to have_http_status(:ok)
    expect(AsaasWebhookEvent.find_by(asaas_event_id: "evt_1")).to be_present
  end

  it "processa o evento e ativa a assinatura" do
    perform_enqueued_jobs { post_webhook }

    expect(subscription.reload).to be_active
    expect(AsaasWebhookEvent.find_by(asaas_event_id: "evt_1")).to be_processed
  end

  it "rejeita requisição sem o token" do
    post_webhook(token: nil)

    expect(response).to have_http_status(:unauthorized)
    expect(AsaasWebhookEvent.count).to be_zero
  end

  it "rejeita requisição com token errado" do
    post_webhook(token: "token-errado")

    expect(response).to have_http_status(:unauthorized)
  end

  it "responde 400 para corpo inválido" do
    post webhooks_asaas_path,
         params: "isto-nao-e-json",
         headers: { "CONTENT_TYPE" => "application/json", "asaas-access-token" => secret }

    expect(response).to have_http_status(:bad_request)
  end

  it "responde 400 quando falta o identificador do evento" do
    post_webhook(body: { event: "PAYMENT_CONFIRMED" })

    expect(response).to have_http_status(:bad_request)
  end

  describe "idempotência" do
    it "guarda o evento uma única vez mesmo com reenvios" do
      5.times { post_webhook }

      expect(AsaasWebhookEvent.where(asaas_event_id: "evt_1").count).to eq(1)
      expect(response).to have_http_status(:ok)
    end

    it "não reprocessa um evento já concluído" do
      perform_enqueued_jobs { post_webhook }
      subscription.update!(status: :past_due)

      expect { post_webhook }.not_to have_enqueued_job(Asaas::WebhookJob)
      expect(subscription.reload).to be_past_due
    end
  end

  it "aceita eventos de assinaturas desconhecidas sem erro" do
    perform_enqueued_jobs do
      post_webhook(body: payload.merge(payment: { subscription: "sub_zzz" }))
    end

    expect(response).to have_http_status(:ok)
  end
end

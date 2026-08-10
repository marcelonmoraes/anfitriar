# frozen_string_literal: true

module Webhooks
  class AsaasController < ActionController::Base
    # Endpoint máquina-a-máquina: sem sessão, sem CSRF, autenticado por token.
    skip_forgery_protection

    before_action :authenticate_webhook

    def create
      event = AsaasWebhookEvent.create_with(
        event_type: payload["event"],
        payload: payload
      ).find_or_create_by!(asaas_event_id: payload.fetch("id"))

      Asaas::WebhookJob.perform_later(event.id) unless event.processed?

      head :ok
    rescue KeyError, JSON::ParserError
      head :bad_request
    end

    private
      def payload
        @payload ||= JSON.parse(raw_body)
      end

      def raw_body
        @raw_body ||= request.body.read
      end

      # O Asaas envia o token configurado no painel a cada requisição.
      def authenticate_webhook
        provided = request.headers["asaas-access-token"].to_s
        expected = Asaas::Configuration.webhook_secret

        return if provided.present? &&
                  ActiveSupport::SecurityUtils.secure_compare(provided, expected)

        Rails.logger.warn("[Asaas] Webhook rejeitado (token inválido) de #{request.remote_ip}")
        head :unauthorized
      end
  end
end

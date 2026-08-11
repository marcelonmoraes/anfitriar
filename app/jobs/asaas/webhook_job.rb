# frozen_string_literal: true

module Asaas
  class WebhookJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    discard_on ActiveRecord::RecordNotFound

    def perform(event_id)
      event = AsaasWebhookEvent.find(event_id)

      event.with_lock do
        return if event.processed?

        WebhookProcessor.new(event).process!
        event.mark_processed!
      end
    rescue StandardError => e
      Rails.logger.error("[Asaas] Falha ao processar webhook #{event_id}: #{e.message}")
      event&.mark_failed!(e.message)
      raise
    end
  end
end

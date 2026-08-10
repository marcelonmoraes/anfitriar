# frozen_string_literal: true

module Admin
  module WebhookEvents
    class ReprocessingsController < Admin::ApplicationController
      def create
        event = AsaasWebhookEvent.find(params[:webhook_event_id])
        event.update!(processed_at: nil, error_message: nil)
        Asaas::WebhookJob.perform_later(event.id)

        redirect_back fallback_location: admin_root_path,
                      notice: "Webhook #{event.event_type} enfileirado para reprocessamento."
      end
    end
  end
end

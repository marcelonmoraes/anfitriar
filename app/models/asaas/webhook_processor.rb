# frozen_string_literal: true

module Asaas
  # Traduz um evento do Asaas em mudanças de estado da assinatura.
  # O payload é sempre um Hash com chaves string (vindo da coluna jsonb).
  class WebhookProcessor
    HANDLERS = {
      "SUBSCRIPTION_CREATED" => :subscription_created,
      "SUBSCRIPTION_UPDATED" => :subscription_updated,
      "SUBSCRIPTION_DELETED" => :subscription_deleted,
      "PAYMENT_CONFIRMED" => :payment_confirmed,
      "PAYMENT_RECEIVED" => :payment_confirmed,
      "PAYMENT_OVERDUE" => :payment_overdue,
      "PAYMENT_REFUNDED" => :payment_refunded,
      "PAYMENT_DELETED" => :payment_refunded
    }.freeze

    def initialize(event)
      @event = event
      @payload = event.payload
    end

    def process!
      handler = HANDLERS[event.event_type]
      return unless handler # Eventos não assinados são ignorados com sucesso.

      subscription = find_subscription
      return unless subscription

      event.update!(subscription: subscription) if event.subscription_id.nil?
      public_send(handler, subscription)
    end

    def subscription_created(subscription)
      subscription.pending! if subscription.trial?
    end

    def subscription_updated(subscription)
      return unless remote_subscription["status"] == "INACTIVE"

      deactivate(subscription)
    end

    def subscription_deleted(subscription)
      deactivate(subscription)
    end

    def payment_confirmed(subscription)
      paid_at = parse_date(payment["paymentDate"] || payment["confirmedDate"]) || Time.current
      was_recovered = subscription.past_due?

      subscription.renew_period!(paid_at)
      subscription.update!(status: :active, canceled_at: nil, canceled_by: nil)

      if was_recovered || !subscription.previously_new_record?
        SubscriptionMailer.payment_confirmed(subscription).deliver_later
      end
    end

    def payment_overdue(subscription)
      return if subscription.past_due?

      subscription.past_due!
      SubscriptionMailer.payment_overdue(subscription).deliver_later
    end

    def payment_refunded(subscription)
      subscription.past_due! unless subscription.canceled?
    end

    private
      attr_reader :event, :payload

      def payment
        payload["payment"] || {}
      end

      def remote_subscription
        payload["subscription"] || {}
      end

      def asaas_subscription_id
        remote_subscription["id"] || payment["subscription"]
      end

      def find_subscription
        event.subscription || Subscription.find_by(asaas_subscription_id: asaas_subscription_id)
      end

      def deactivate(subscription)
        return if subscription.canceled?

        subscription.update!(status: :canceled, canceled_at: Time.current, canceled_by: :system)
        SubscriptionMailer.canceled(subscription).deliver_later
      end

      def parse_date(value)
        return if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end
  end
end

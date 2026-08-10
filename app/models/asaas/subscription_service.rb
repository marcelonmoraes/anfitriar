# frozen_string_literal: true

module Asaas
  class SubscriptionService
    CYCLES = {
      "monthly" => "MONTHLY",
      "quarterly" => "QUARTERLY",
      "semiannual" => "SEMIANNUAL",
      "annual" => "ANNUAL"
    }.freeze

    def initialize(client: Client.new, customer_service: CustomerService.new)
      @client = client
      @customer_service = customer_service
    end

    # Cria a assinatura recorrente no Asaas cobrando o cartão tokenizado.
    def create(subscription, credit_card, remote_ip:)
      customer_id = @customer_service.synchronize(subscription.host)
      response = @client.create_subscription(
        attributes_for(subscription, customer_id, credit_card, remote_ip)
      )

      subscription.update!(
        asaas_subscription_id: response["id"],
        credit_card: credit_card,
        status: :pending,
        current_period_start: Time.current
      )

      response
    end

    def change_credit_card(subscription, credit_card, remote_ip:)
      @client.update_subscription(subscription.asaas_subscription_id,
        creditCardToken: credit_card.asaas_token,
        remoteIp: remote_ip
      )
      subscription.update!(credit_card: credit_card)
    end

    def change_plan(subscription)
      @client.update_subscription(subscription.asaas_subscription_id,
        value: subscription.price,
        cycle: CYCLES.fetch(subscription.billing_cycle),
        description: description_for(subscription),
        updatePendingPayments: true
      )
    end

    def cancel(subscription, canceled_by:)
      @client.cancel_subscription(subscription.asaas_subscription_id) if subscription.asaas_subscription_id.present?

      subscription.update!(status: :canceled, canceled_at: Time.current, canceled_by: canceled_by)
    end

    private
      def attributes_for(subscription, customer_id, credit_card, remote_ip)
        {
          customer: customer_id,
          billingType: "CREDIT_CARD",
          value: subscription.price,
          nextDueDate: Date.current.to_fs(:iso8601),
          cycle: CYCLES.fetch(subscription.billing_cycle),
          description: description_for(subscription),
          externalReference: subscription.id.to_s,
          creditCardToken: credit_card.asaas_token,
          remoteIp: remote_ip
        }
      end

      def description_for(subscription)
        "Anfitriar — plano #{subscription.plan.name} (#{I18n.t("subscriptions.cycles.#{subscription.billing_cycle}")})"
      end
  end
end

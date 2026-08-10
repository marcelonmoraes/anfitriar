# frozen_string_literal: true

class SubscriptionMailer < ApplicationMailer
  def payment_confirmed(subscription)
    @subscription = subscription
    @host = subscription.host

    mail to: @host.email_address, subject: "Pagamento confirmado — plano #{subscription.plan.name}"
  end

  def payment_overdue(subscription)
    @subscription = subscription
    @host = subscription.host

    mail to: @host.email_address, subject: "Não conseguimos processar seu pagamento"
  end

  def canceled(subscription)
    @subscription = subscription
    @host = subscription.host

    mail to: @host.email_address, subject: "Sua assinatura foi cancelada"
  end
end

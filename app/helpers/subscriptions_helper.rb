module SubscriptionsHelper
  STATUS_LABELS = {
    "trial" => "Período de teste",
    "active" => "Ativa",
    "past_due" => "Pagamento pendente",
    "canceled" => "Cancelada"
  }.freeze

  def subscription_status_label(subscription)
    STATUS_LABELS.fetch(subscription.status, subscription.status)
  end
end

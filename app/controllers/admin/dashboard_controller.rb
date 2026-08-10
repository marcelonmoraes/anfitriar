class Admin::DashboardController < Admin::ApplicationController
  def show
    @total_hosts = Host.count
    @counts_by_status = Subscription.group(:status).count

    # MRR considera quem gera receita recorrente hoje.
    @mrr_cents = Subscription.billable.includes(:plan).sum(&:mrr_cents)
    @arr_cents = @mrr_cents * 12

    converted = @counts_by_status.values_at("active", "past_due").compact.sum
    finished_trial = converted + @counts_by_status.fetch("canceled", 0)
    @conversion_rate = finished_trial.positive? ? ((converted.to_f / finished_trial) * 100).round(1) : 0

    @recent_hosts = Host.includes(subscription: :plan).order(created_at: :desc).limit(5)
    @failed_webhooks = AsaasWebhookEvent.failed.pending.recent.limit(5)
  end
end

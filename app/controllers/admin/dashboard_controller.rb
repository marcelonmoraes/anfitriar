class Admin::DashboardController < Admin::ApplicationController
  def show
    @total_hosts = Host.count
    @active_subscriptions = Subscription.where(status: "active")
    @trial_subscriptions = Subscription.where(status: "trial")
    @past_due_subscriptions = Subscription.where(status: "past_due")
    @canceled_subscriptions = Subscription.where(status: "canceled")

    # MRR (Monthly Recurring Revenue)
    @mrr_cents = @active_subscriptions.includes(:plan).sum(&:mrr_cents)
    @arr_cents = @mrr_cents * 12

    # Conversion rate (hosts with active subscription / total hosts who finished trial or active)
    total_converters = Subscription.where(status: %w[active past_due canceled]).count
    @conversion_rate = total_converters.positive? ? ((@active_subscriptions.count.to_f / total_converters) * 100).round(1) : 0

    @recent_hosts = Host.order(created_at: :desc).limit(5)
  end
end

class Subscription < ApplicationRecord
  STATUSES = %w[trial active past_due canceled].freeze
  CYCLES = %w[monthly quarterly semiannual annual].freeze

  belongs_to :host
  belongs_to :plan

  enum :status, STATUSES.index_by(&:itself), default: "trial"
  enum :billing_cycle, CYCLES.index_by(&:itself)

  validates :host_id, uniqueness: true
  validates :trial_ends_at, presence: true, if: :trial?

  def self.start_trial_for(host)
    create!(
      host: host,
      plan: Plan.find_by!(slug: "pro"),
      status: :trial,
      trial_ends_at: PlatformConfiguration.current.trial_days.days.from_now
    )
  end

  def trial_days_left
    return 0 unless trial? && trial_ends_at
    [ (trial_ends_at.to_date - Date.current).to_i, 0 ].max
  end

  def mrr_cents
    return 0 unless plan

    case billing_cycle
    when "monthly" then plan.monthly_price_cents
    when "quarterly" then (plan.quarterly_price_cents / 3.0).round
    when "semiannual" then (plan.semiannual_price_cents / 6.0).round
    when "annual" then (plan.annual_price_cents / 12.0).round
    else plan.monthly_price_cents
    end
  end
end

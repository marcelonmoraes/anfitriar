class Subscription < ApplicationRecord
  STATUSES = %w[trial pending active past_due canceled].freeze
  CYCLES = %w[monthly quarterly semiannual annual].freeze
  CANCELERS = %w[host admin system].freeze

  belongs_to :host
  belongs_to :plan
  belongs_to :credit_card, optional: true
  has_many :asaas_webhook_events, dependent: :nullify

  enum :status, STATUSES.index_by(&:itself), default: "trial"
  enum :billing_cycle, CYCLES.index_by(&:itself)
  enum :canceled_by, CANCELERS.index_by(&:itself), prefix: :canceled_by

  validates :host_id, uniqueness: true
  validates :trial_ends_at, presence: true, if: :trial?

  scope :billable, -> { where(status: %w[active past_due]) }

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

  def trial_expired?
    trial? && trial_ends_at.present? && trial_ends_at.past?
  end

  # Regra de acesso ao guia público: trial válido ou assinatura em dia.
  def grants_access?
    return trial_ends_at.present? && trial_ends_at.future? if trial?

    active? || past_due?
  end

  def price_cents
    return 0 unless plan

    case billing_cycle
    when "quarterly"  then plan.quarterly_price_cents
    when "semiannual" then plan.semiannual_price_cents
    when "annual"     then plan.annual_price_cents
    else plan.monthly_price_cents
    end
  end

  def price
    price_cents / 100.0
  end

  def mrr_cents
    return 0 unless plan

    case billing_cycle
    when "quarterly"  then (plan.quarterly_price_cents / 3.0).round
    when "semiannual" then (plan.semiannual_price_cents / 6.0).round
    when "annual"     then (plan.annual_price_cents / 12.0).round
    else plan.monthly_price_cents
    end
  end

  def cycle_duration
    case billing_cycle
    when "quarterly"  then 3.months
    when "semiannual" then 6.months
    when "annual"     then 1.year
    else 1.month
    end
  end

  def renew_period!(starts_at)
    update!(
      current_period_start: starts_at,
      current_period_end: starts_at + cycle_duration
    )
  end
end

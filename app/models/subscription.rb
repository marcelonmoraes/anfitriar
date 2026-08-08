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
end

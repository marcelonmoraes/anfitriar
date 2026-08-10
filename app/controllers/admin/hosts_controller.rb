class Admin::HostsController < Admin::ApplicationController
  before_action :set_host, only: %i[show]

  def index
    @hosts = Host.includes(subscription: :plan).order(created_at: :desc)

    if params[:status].present?
      @hosts = @hosts.joins(:subscription).where(subscriptions: { status: params[:status] })
    end

    if params[:search].present?
      term = "%#{params[:search].strip.downcase}%"
      @hosts = @hosts.where("LOWER(hosts.name) LIKE ? OR LOWER(hosts.email_address) LIKE ?", term, term)
    end
  end

  def show
    @subscription = @host.subscription
    @credit_cards = @host.credit_cards.default_first
    @webhook_events = AsaasWebhookEvent.where(subscription: @subscription).recent.limit(10)
    @properties_count = @host.properties.count
    @guests_count = @host.guests.count

    # Analytics sem conteúdo: % média de preenchimento dos guias
    properties = @host.properties.includes(:cards)
    if properties.any?
      total_progress = properties.map { |p| p.guide_progress }.sum { |prog| prog[:total].positive? ? (prog[:filled].to_f / prog[:total] * 100) : 0 }
      @avg_guide_progress = (total_progress / properties.size).round
    else
      @avg_guide_progress = 0
    end
  end

  private

  def set_host
    @host = Host.find(params[:id])
  end
end

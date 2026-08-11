class Admin::SubscriptionsController < Admin::ApplicationController
  before_action :set_host
  before_action :set_subscription, only: %i[edit update]

  def new
    @subscription = @host.build_subscription
    @plans = Plan.order(:name)
  end

  def create
    @subscription = @host.build_subscription(subscription_params)
    if @subscription.save
      redirect_to admin_host_path(@host), notice: "Assinatura criada com sucesso."
    else
      @plans = Plan.order(:name)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @plans = Plan.order(:name)
  end

  def update
    @subscription.assign_attributes(subscription_params)
    pricing_changed = @subscription.plan_id_changed? || @subscription.billing_cycle_changed?
    canceling = @subscription.status_changed?(to: "canceled")

    if @subscription.save
      synchronize_with_asaas(pricing_changed, canceling)
      redirect_to admin_host_path(@host), notice: "Assinatura atualizada com sucesso."
    else
      @plans = Plan.order(:name)
      render :edit, status: :unprocessable_content
    end
  rescue Asaas::Client::Error => e
    redirect_to admin_host_path(@host),
                alert: "Assinatura salva, mas o Asaas recusou a sincronização: #{e.message}"
  end

  private
    def set_host
      @host = Host.find(params[:host_id])
    end

    def set_subscription
      @subscription = @host.subscription || @host.build_subscription
    end

    def subscription_params
      params.expect(subscription: [ :plan_id, :billing_cycle, :status, :trial_ends_at ])
    end

    # O painel é a fonte da verdade para o Owner, mas quem cobra é o Asaas:
    # mudanças de preço ou cancelamento precisam chegar lá.
    def synchronize_with_asaas(pricing_changed, canceling)
      return if @subscription.asaas_subscription_id.blank?

      service = Asaas::SubscriptionService.new

      if canceling
        service.cancel(@subscription, canceled_by: :admin)
      elsif pricing_changed
        service.change_plan(@subscription)
      end
    end
end

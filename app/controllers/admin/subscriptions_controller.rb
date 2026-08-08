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
    if @subscription.update(subscription_params)
      redirect_to admin_host_path(@host), notice: "Assinatura atualizada com sucesso."
    else
      @plans = Plan.order(:name)
      render :edit, status: :unprocessable_content
    end
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
end
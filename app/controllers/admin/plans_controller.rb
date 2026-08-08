class Admin::PlansController < Admin::ApplicationController
  before_action :set_plan, only: %i[show edit update destroy]

  def index
    @plans = Plan.order(:monthly_price_cents)
  end

  def show
  end

  def new
    @plan = Plan.new
  end

  def create
    @plan = Plan.new(plan_params)
    if @plan.save
      redirect_to admin_plans_path, notice: "Plano criado."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      redirect_to admin_plans_path, notice: "Plano atualizado."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @plan.destroy
    redirect_to admin_plans_path, notice: "Plano excluído."
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end

  def plan_params
    params.expect(plan: [ :name, :slug, :monthly_price_cents, :quarterly_price_cents, :semiannual_price_cents, :annual_price_cents, :max_properties ])
  end
end
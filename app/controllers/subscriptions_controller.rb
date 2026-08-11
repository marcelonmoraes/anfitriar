# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  before_action :set_subscription

  def show
    @credit_cards = Current.host.credit_cards.default_first
  end

  def new
    redirect_to account_subscription_path, notice: t(".already_active") and return if @subscription.active?

    @plans = Plan.order(:monthly_price_cents)
    @credit_cards = Current.host.credit_cards.default_first
    @credit_card_form = CreditCardForm.new(holder_name: Current.host.name)
    @subscription.plan_id ||= @plans.first&.id
    @subscription.billing_cycle ||= "monthly"
  end

  def create
    @subscription.assign_attributes(subscription_params)
    @subscription.status = :pending
    @subscription.trial_ends_at = nil
    @subscription.current_period_start = Time.current

    unless @subscription.valid?
      return render_new(status: :unprocessable_content)
    end

    credit_card = resolve_credit_card
    return render_new(status: :unprocessable_content) if credit_card.nil?

    @subscription.save!
    Asaas::SubscriptionService.new.create(@subscription, credit_card, remote_ip: request.remote_ip)

    redirect_to account_subscription_path, notice: t(".created")
  rescue Asaas::CreditCardService::MissingBillingProfile
    redirect_to account_path, alert: t(".missing_billing_profile")
  rescue Asaas::Client::Error => e
    flash.now[:alert] = e.message
    render_new(status: :unprocessable_content)
  end

  # Troca de plano/ciclo da assinatura vigente.
  def update
    @subscription.assign_attributes(subscription_params.slice(:plan_id, :billing_cycle))

    if @subscription.save
      Asaas::SubscriptionService.new.change_plan(@subscription)
      redirect_to account_subscription_path, notice: t(".updated")
    else
      @plans = Plan.order(:monthly_price_cents)
      render :edit, status: :unprocessable_content
    end
  rescue Asaas::Client::Error => e
    redirect_to account_subscription_path, alert: e.message
  end

  def edit
    @plans = Plan.order(:monthly_price_cents)
  end

  def destroy
    Asaas::SubscriptionService.new.cancel(@subscription, canceled_by: :host)
    redirect_to account_subscription_path, notice: t(".canceled")
  rescue Asaas::Client::Error => e
    redirect_to account_subscription_path, alert: e.message
  end

  private
    def set_subscription
      @subscription = Current.host.subscription || Current.host.build_subscription
    end

    def subscription_params
      params.expect(subscription: [ :plan_id, :billing_cycle ])
    end

    # Usa um cartão já salvo ou tokeniza o novo informado no checkout.
    def resolve_credit_card
      if params[:credit_card_id].present?
        return Current.host.credit_cards.find(params[:credit_card_id])
      end

      @credit_card_form = CreditCardForm.new(credit_card_params)
      return nil unless @credit_card_form.valid?

      Asaas::CreditCardService.new.tokenize(
        host: Current.host,
        card: @credit_card_form,
        remote_ip: request.remote_ip
      )
    rescue Asaas::Client::InvalidRequestError => e
      @credit_card_form.errors.add(:base, e.message)
      nil
    end

    def credit_card_params
      params.expect(credit_card: [ :holder_name, :number, :expiry, :cvv, :document ])
    end

    def render_new(status:)
      @plans = Plan.order(:monthly_price_cents)
      @credit_cards = Current.host.credit_cards.default_first
      @credit_card_form ||= CreditCardForm.new
      render :new, status: status
    end
end

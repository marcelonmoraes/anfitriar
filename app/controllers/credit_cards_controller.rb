# frozen_string_literal: true

class CreditCardsController < ApplicationController
  before_action :set_credit_card, only: %i[destroy]

  def index
    @credit_cards = Current.host.credit_cards.default_first
    @credit_card_form = CreditCardForm.new(holder_name: Current.host.name)
  end

  def create
    @credit_card_form = CreditCardForm.new(credit_card_params)

    unless @credit_card_form.valid?
      @credit_cards = Current.host.credit_cards.default_first
      return render :index, status: :unprocessable_content
    end

    Asaas::CreditCardService.new.tokenize(
      host: Current.host,
      card: @credit_card_form,
      remote_ip: request.remote_ip
    )

    redirect_to account_credit_cards_path, notice: t(".created")
  rescue Asaas::CreditCardService::MissingBillingProfile
    redirect_to account_path, alert: t(".missing_billing_profile")
  rescue Asaas::Client::Error => e
    @credit_cards = Current.host.credit_cards.default_first
    @credit_card_form.errors.add(:base, e.message)
    render :index, status: :unprocessable_content
  end

  def destroy
    if @credit_card.subscriptions.billable.exists?
      redirect_to account_credit_cards_path, alert: t(".in_use") and return
    end

    @credit_card.destroy!
    redirect_to account_credit_cards_path, notice: t(".destroyed")
  end

  private
    def set_credit_card
      @credit_card = Current.host.credit_cards.find(params[:id])
    end

    def credit_card_params
      params.expect(credit_card: [ :holder_name, :number, :expiry, :cvv, :document ])
    end
end

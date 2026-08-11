# frozen_string_literal: true

module CreditCards
  class DefaultsController < ApplicationController
    def create
      credit_card = Current.host.credit_cards.find(params[:credit_card_id])
      credit_card.make_default!

      subscription = Current.host.subscription
      if subscription&.asaas_subscription_id.present? && (subscription.active? || subscription.past_due?)
        Asaas::SubscriptionService.new.change_credit_card(
          subscription, credit_card, remote_ip: request.remote_ip
        )
      end

      redirect_to account_credit_cards_path, notice: t(".created")
    rescue Asaas::Client::Error => e
      redirect_to account_credit_cards_path, alert: e.message
    end
  end
end

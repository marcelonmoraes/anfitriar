# frozen_string_literal: true

module Asaas
  # Tokeniza cartões no Asaas e persiste apenas o token e os dados não sensíveis.
  # O PAN e o CVV nunca são gravados nem logados.
  class CreditCardService
    class MissingBillingProfile < StandardError; end

    def initialize(client: Client.new, customer_service: CustomerService.new)
      @client = client
      @customer_service = customer_service
    end

    def tokenize(host:, card:, remote_ip:)
      raise MissingBillingProfile unless host.billing_profile_complete?

      customer_id = @customer_service.synchronize(host)
      response = @client.tokenize_credit_card(
        customer: customer_id,
        creditCard: card_attributes(card),
        creditCardHolderInfo: holder_attributes(host, card),
        remoteIp: remote_ip
      )

      host.credit_cards.create!(
        asaas_token: response["creditCardToken"],
        brand: response["creditCardBrand"],
        last_four: response["creditCardNumber"],
        holder_name: card.holder_name,
        expiry_month: card.expiry_month,
        expiry_year: card.expiry_year
      )
    end

    private
      def card_attributes(card)
        {
          holderName: card.holder_name,
          number: card.number,
          expiryMonth: format("%02d", card.expiry_month),
          expiryYear: card.expiry_year.to_s,
          ccv: card.cvv
        }
      end

      def holder_attributes(host, card)
        {
          name: card.holder_name,
          email: host.email_address,
          cpfCnpj: card.document.presence || host.cpf_cnpj,
          postalCode: host.postal_code,
          addressNumber: host.address_number,
          phone: host.phone,
          mobilePhone: host.phone
        }.compact_blank
      end
  end
end

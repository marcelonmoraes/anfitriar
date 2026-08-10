# frozen_string_literal: true

module Asaas
  class CustomerService
    def initialize(client: Client.new)
      @client = client
    end

    # Garante que o anfitrião tenha um customer no Asaas, criando na primeira vez
    # e mantendo os dados sincronizados nas seguintes.
    def synchronize(host)
      if host.asaas_customer_id.present?
        @client.update_customer(host.asaas_customer_id, attributes_for(host))
        host.asaas_customer_id
      else
        response = @client.create_customer(attributes_for(host))
        host.update!(asaas_customer_id: response["id"])
        response["id"]
      end
    end

    private
      def attributes_for(host)
        {
          name: host.name,
          email: host.email_address,
          mobilePhone: host.phone,
          cpfCnpj: host.cpf_cnpj,
          postalCode: host.postal_code,
          addressNumber: host.address_number,
          externalReference: host.id.to_s,
          # Toda comunicação com o anfitrião é feita pelo Anfitriar.
          notificationDisabled: true
        }.compact_blank
      end
  end
end

# frozen_string_literal: true

module Asaas
  module Configuration
    PRODUCTION_URL = "https://api.asaas.com/v3"
    SANDBOX_URL = "https://api-sandbox.asaas.com/v3"

    class << self
      # Chave secreta: exclusiva do backend, nunca exposta em views.
      def api_key
        ENV.fetch("ASAAS_API_KEY")
      end

      # Chave pública: usada pelo browser para tokenizar cartões.
      def public_key
        ENV.fetch("ASAAS_PUBLIC_KEY", nil)
      end

      def webhook_secret
        ENV.fetch("ASAAS_WEBHOOK_SECRET")
      end

      def base_url
        production? ? PRODUCTION_URL : SANDBOX_URL
      end

      def environment
        production? ? "production" : "sandbox"
      end

      def production?
        ENV.fetch("ASAAS_ENVIRONMENT", Rails.env) == "production"
      end

      def headers
        {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "Anfitriar",
          "access_token" => api_key
        }
      end
    end
  end
end

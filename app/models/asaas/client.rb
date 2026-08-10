# frozen_string_literal: true

module Asaas
  class Client
    class Error < StandardError
      attr_reader :errors, :status

      def initialize(message, errors: [], status: nil)
        @errors = errors
        @status = status
        super(message)
      end
    end

    class AuthenticationError < Error; end
    class NotFoundError < Error; end
    class InvalidRequestError < Error; end
    class ConnectionError < Error; end

    def initialize(connection: nil)
      @connection = connection || build_connection
    end

    # -- Customers ----------------------------------------------------------
    def create_customer(attributes)
      request(:post, "/customers", attributes)
    end

    def update_customer(customer_id, attributes)
      request(:put, "/customers/#{customer_id}", attributes)
    end

    def find_customer(customer_id)
      request(:get, "/customers/#{customer_id}")
    end

    # -- Credit cards -------------------------------------------------------
    def tokenize_credit_card(attributes)
      request(:post, "/creditCard/tokenizeCreditCard", attributes)
    end

    # -- Subscriptions ------------------------------------------------------
    def create_subscription(attributes)
      request(:post, "/subscriptions", attributes)
    end

    def update_subscription(subscription_id, attributes)
      request(:put, "/subscriptions/#{subscription_id}", attributes)
    end

    def update_subscription_credit_card(subscription_id, attributes)
      request(:put, "/subscriptions/#{subscription_id}/creditCard", attributes)
    end

    def find_subscription(subscription_id)
      request(:get, "/subscriptions/#{subscription_id}")
    end

    def cancel_subscription(subscription_id)
      request(:delete, "/subscriptions/#{subscription_id}")
    end

    def subscription_payments(subscription_id)
      request(:get, "/subscriptions/#{subscription_id}/payments")
    end

    private
      def request(method, path, body = nil)
        response = @connection.public_send(method, path, body)
        response.body
      rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => e
        raise AuthenticationError.new("Credenciais Asaas inválidas.", status: e.response_status)
      rescue Faraday::ResourceNotFound => e
        raise NotFoundError.new("Recurso não encontrado no Asaas.", status: e.response_status)
      rescue Faraday::BadRequestError, Faraday::UnprocessableEntityError => e
        raise InvalidRequestError.new(error_description(e), errors: error_list(e), status: e.response_status)
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        raise ConnectionError.new("Não foi possível conectar ao Asaas: #{e.message}")
      rescue Faraday::Error => e
        raise Error.new(error_description(e), errors: error_list(e), status: e.response_status)
      end

      # O Asaas devolve { "errors": [{ "code": ..., "description": ... }] }.
      def error_list(exception)
        body = exception.response_body
        body = JSON.parse(body) rescue nil if body.is_a?(String)
        return [] unless body.is_a?(Hash)

        Array(body["errors"])
      end

      def error_description(exception)
        descriptions = error_list(exception).filter_map { |e| e["description"] }
        return descriptions.join(" ") if descriptions.any?

        "Falha na comunicação com o Asaas."
      end

      def build_connection
        Faraday.new(url: Configuration.base_url, headers: Configuration.headers) do |conn|
          conn.request :json
          conn.request :retry,
                       max: 2,
                       interval: 0.5,
                       backoff_factor: 2,
                       retry_statuses: [ 429, 500, 502, 503, 504 ],
                       methods: %i[get],
                       exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
          conn.response :json
          conn.response :raise_error
          conn.options.timeout = 15
          conn.options.open_timeout = 5
        end
      end
  end
end

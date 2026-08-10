# frozen_string_literal: true

# Cliente Asaas de mentira: registra as chamadas e devolve respostas plausíveis,
# sem tocar a rede.
class FakeAsaasClient
  attr_reader :calls

  def initialize(overrides = {})
    @calls = []
    @overrides = overrides
  end

  def create_customer(attributes)
    record(:create_customer, attributes)
    { "id" => "cus_fake_1" }
  end

  def update_customer(customer_id, attributes)
    record(:update_customer, [ customer_id, attributes ])
    { "id" => customer_id }
  end

  def tokenize_credit_card(attributes)
    record(:tokenize_credit_card, attributes)
    raise @overrides[:tokenize_error] if @overrides[:tokenize_error]

    {
      "creditCardToken" => "tok_fake_1",
      "creditCardBrand" => "VISA",
      "creditCardNumber" => "4242"
    }
  end

  def create_subscription(attributes)
    record(:create_subscription, attributes)
    { "id" => "sub_fake_1", "status" => "ACTIVE" }
  end

  def update_subscription(subscription_id, attributes)
    record(:update_subscription, [ subscription_id, attributes ])
    { "id" => subscription_id }
  end

  def update_subscription_credit_card(subscription_id, attributes)
    record(:update_subscription_credit_card, [ subscription_id, attributes ])
    { "id" => subscription_id }
  end

  def cancel_subscription(subscription_id)
    record(:cancel_subscription, subscription_id)
    { "deleted" => true }
  end

  def called?(name) = calls.any? { |call| call.first == name }

  def payload_for(name) = calls.find { |call| call.first == name }&.last

  private
    def record(name, attributes) = @calls << [ name, attributes ]
end

module AsaasHelpers
  def fake_asaas_client(overrides = {})
    client = FakeAsaasClient.new(overrides)
    customer_service = Asaas::CustomerService.new(client: client)

    allow(Asaas::Client).to receive(:new).and_return(client)
    allow(Asaas::CustomerService).to receive(:new).and_return(customer_service)

    client
  end
end

RSpec.configure do |config|
  config.include AsaasHelpers
end

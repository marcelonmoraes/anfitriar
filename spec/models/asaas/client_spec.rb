require "rails_helper"

RSpec.describe Asaas::Client do
  def client_for(status, body)
    stubs = Faraday::Adapter::Test::Stubs.new
    yield stubs if block_given?

    connection = Faraday.new do |conn|
      conn.request :json
      conn.response :json
      conn.response :raise_error
      conn.adapter :test, stubs do |stub|
        stub.post("/customers") { [ status, { "Content-Type" => "application/json" }, body ] }
      end
    end

    described_class.new(connection: connection)
  end

  it "devolve o corpo da resposta em caso de sucesso" do
    client = client_for(200, { "id" => "cus_1" }.to_json)

    expect(client.create_customer(name: "Ana")).to eq("id" => "cus_1")
  end

  it "traduz a recusa de validação com a mensagem do Asaas" do
    body = { "errors" => [ { "code" => "invalid_creditCard", "description" => "Cartão recusado." } ] }.to_json
    client = client_for(400, body)

    expect { client.create_customer(name: "Ana") }
      .to raise_error(Asaas::Client::InvalidRequestError, "Cartão recusado.")
  end

  it "sinaliza credencial inválida" do
    client = client_for(401, {}.to_json)

    expect { client.create_customer(name: "Ana") }.to raise_error(Asaas::Client::AuthenticationError)
  end

  it "sinaliza recurso inexistente" do
    client = client_for(404, {}.to_json)

    expect { client.create_customer(name: "Ana") }.to raise_error(Asaas::Client::NotFoundError)
  end

  it "usa mensagem genérica quando o Asaas não detalha o erro" do
    client = client_for(500, {}.to_json)

    expect { client.create_customer(name: "Ana") }
      .to raise_error(Asaas::Client::Error, "Falha na comunicação com o Asaas.")
  end

  describe "configuração" do
    it "aponta para o sandbox fora de produção" do
      allow(Asaas::Configuration).to receive(:production?).and_return(false)

      expect(Asaas::Configuration.base_url).to eq(Asaas::Configuration::SANDBOX_URL)
    end

    it "aponta para produção quando configurado" do
      allow(Asaas::Configuration).to receive(:production?).and_return(true)

      expect(Asaas::Configuration.base_url).to eq(Asaas::Configuration::PRODUCTION_URL)
    end

    it "envia a chave secreta no cabeçalho esperado pelo Asaas" do
      allow(Asaas::Configuration).to receive(:api_key).and_return("chave-secreta")

      expect(Asaas::Configuration.headers["access_token"]).to eq("chave-secreta")
    end
  end
end

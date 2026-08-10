require "rails_helper"

RSpec.describe "Cartões do anfitrião", type: :request do
  let!(:host) { create(:host, :with_billing_profile) }
  let(:card_params) do
    { holder_name: "ANA ANFITRIA", number: "4242 4242 4242 4242",
      expiry: "12/#{(Date.current.year + 2).to_s.last(2)}", cvv: "123" }
  end

  before { sign_in host }

  it "lista os cartões com o padrão em primeiro" do
    primeiro = create(:credit_card, host: host, last_four: "1111")
    segundo = create(:credit_card, host: host, last_four: "2222")
    segundo.make_default!

    get account_credit_cards_path

    expect(response.body.index("2222")).to be < response.body.index("1111")
    expect(primeiro.reload).not_to be_default
  end

  it "cadastra um cartão novo" do
    client = fake_asaas_client

    post account_credit_cards_path, params: { credit_card: card_params }

    expect(response).to redirect_to(account_credit_cards_path)
    expect(host.credit_cards.count).to eq(1)
    expect(client).to be_called(:tokenize_credit_card)
  end

  it "recusa cartão vencido sem chamar o Asaas" do
    client = fake_asaas_client

    post account_credit_cards_path, params: { credit_card: card_params.merge(expiry: "01/20") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(client).not_to be_called(:tokenize_credit_card)
    expect(host.credit_cards).to be_empty
  end

  it "define outro cartão como padrão e atualiza a assinatura ativa" do
    client = fake_asaas_client
    create(:credit_card, host: host)
    novo = create(:credit_card, host: host)
    create(:subscription, host: host, status: :active, asaas_subscription_id: "sub_1", trial_ends_at: nil)

    post account_credit_card_default_path(novo)

    expect(response).to redirect_to(account_credit_cards_path)
    expect(novo.reload).to be_default
    expect(client).to be_called(:update_subscription_credit_card)
  end

  it "remove um cartão que não está em uso" do
    credit_card = create(:credit_card, host: host)

    delete account_credit_card_path(credit_card)

    expect(response).to redirect_to(account_credit_cards_path)
    expect(host.credit_cards).to be_empty
  end

  it "protege o cartão usado pela assinatura vigente" do
    credit_card = create(:credit_card, host: host)
    create(:subscription, host: host, status: :active, credit_card: credit_card, trial_ends_at: nil)

    delete account_credit_card_path(credit_card)

    expect(host.credit_cards.reload).to include(credit_card)
  end

  it "não permite mexer no cartão de outro anfitrião" do
    alheio = create(:credit_card, host: create(:host))

    delete account_credit_card_path(alheio)

    expect(response).to have_http_status(:not_found)
    expect(CreditCard.exists?(alheio.id)).to be(true)
  end
end

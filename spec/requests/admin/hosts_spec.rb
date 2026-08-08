require "rails_helper"

RSpec.describe "Admin Hosts", type: :request do
  let!(:owner) { create(:owner) }
  let!(:plan) { create(:plan, slug: "pro", name: "Pro") }
  let!(:host) { create(:host, password: "senha-segura-123") }

  before do
    create(:subscription, host: host, plan: plan, status: :active, billing_cycle: :monthly)
    sign_in_owner owner
  end

  it "lista anfitriões" do
    get admin_hosts_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(host.name)
  end

  it "filtra anfitriões por status da assinatura" do
    get admin_hosts_path, params: { status: "active" }
    expect(response.body).to include(host.name)
  end

  it "busca anfitriões por nome ou e-mail" do
    get admin_hosts_path, params: { search: host.name }
    expect(response.body).to include(host.name)
  end

  it "mostra detalhes do anfitrião com analytics" do
    get admin_host_path(host)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(host.name)
    expect(response.body).to include(host.email_address)
  end
end
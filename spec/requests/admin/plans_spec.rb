require "rails_helper"

RSpec.describe "Admin Plans", type: :request do
  let!(:owner) { create(:owner) }

  before { sign_in_owner owner }

  it "lista planos" do
    get admin_plans_path
    expect(response).to have_http_status(:ok)
  end

  it "cria plano com sucesso" do
    expect {
      post admin_plans_path, params: {
        plan: {
          name: "Plano Ultra",
          slug: "ultra",
          monthly_price_cents: 9900,
          quarterly_price_cents: 26730,
          semiannual_price_cents: 50490,
          annual_price_cents: 89100,
          max_properties: 50
        }
      }
    }.to change(Plan, :count).by(1)

    expect(response).to redirect_to(admin_plans_path)
  end

  it "atualiza plano" do
    plan = create(:plan)
    patch admin_plan_path(plan), params: { plan: { name: "Novo Nome" } }
    expect(response).to redirect_to(admin_plans_path)
    expect(plan.reload.name).to eq("Novo Nome")
  end

  it "exclui plano" do
    plan = create(:plan)
    expect {
      delete admin_plan_path(plan)
    }.to change(Plan, :count).by(-1)
    expect(response).to redirect_to(admin_plans_path)
  end
end

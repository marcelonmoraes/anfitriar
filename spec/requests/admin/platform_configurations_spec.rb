require "rails_helper"

RSpec.describe "Admin Platform Configuration", type: :request do
  let!(:owner) { create(:owner) }

  before { sign_in_owner owner }

  it "edita configurações da plataforma" do
    patch admin_platform_configuration_path, params: {
      platform_configuration: { trial_days: 14, booking_access_margin_days: 5 }
    }
    expect(response).to redirect_to(edit_admin_platform_configuration_path)

    config = PlatformConfiguration.current
    expect(config.trial_days).to eq(14)
    expect(config.booking_access_margin_days).to eq(5)
  end
end

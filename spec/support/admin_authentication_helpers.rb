module AdminAuthenticationHelpers
  def sign_in_owner(owner, password: "senha-admin-123")
    post admin_login_path, params: { email_address: owner.email_address, password: password }
  end
end

RSpec.configure do |config|
  config.include AdminAuthenticationHelpers, type: :request
end

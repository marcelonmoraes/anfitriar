module AuthenticationHelpers
  def sign_in(host, password: "senha-segura-123")
    post session_path, params: { email_address: host.email_address, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end

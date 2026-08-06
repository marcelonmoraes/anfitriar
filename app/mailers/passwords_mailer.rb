class PasswordsMailer < ApplicationMailer
  def reset(host)
    @host = host
    mail subject: "Redefinição de senha — Anfitriar", to: host.email_address
  end
end

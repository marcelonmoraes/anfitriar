class PasswordsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 15.minutes, only: :create,
             with: -> { redirect_to new_password_url, alert: "Muitas tentativas. Aguarde alguns minutos." }
  before_action :set_host_by_token, only: %i[edit update]

  def new
  end

  def create
    if host = Host.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(host).deliver_later
    end
    redirect_to new_session_path,
                notice: "Se este e-mail estiver cadastrado, enviaremos instruções para redefinir a senha."
  end

  def edit
  end

  def update
    if @host.update(params.expect(host: [ :password, :password_confirmation ]))
      @host.sessions.destroy_all
      redirect_to new_session_path, notice: "Senha redefinida. Faça login com a nova senha."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_host_by_token
      @host = Host.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "O link de redefinição é inválido ou expirou."
    end
end

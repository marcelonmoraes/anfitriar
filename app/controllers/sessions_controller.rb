class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_url, alert: "Muitas tentativas. Aguarde alguns minutos." }

  def new
  end

  def create
    if host = Host.authenticate_by(email_address: params[:email_address], password: params[:password])
      start_new_session_for host
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "E-mail ou senha inválidos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Você saiu da sua conta."
  end
end

class Admin::SessionsController < Admin::ApplicationController
  skip_before_action :authenticate_owner!, only: %i[new create]

  layout "admin_login"

  def new
  end

  def create
    owner = Owner.find_by(email_address: params[:email_address])
    if owner&.authenticate(params[:password])
      session[:owner_id] = owner.id
      redirect_to admin_root_path, notice: "Login realizado com sucesso."
    else
      flash.now[:alert] = "E-mail ou senha inválidos."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session.delete(:owner_id)
    redirect_to admin_login_path, notice: "Logout realizado."
  end
end
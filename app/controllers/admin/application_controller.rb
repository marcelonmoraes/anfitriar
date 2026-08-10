class Admin::ApplicationController < ActionController::Base
  layout "admin"
  allow_browser versions: :modern

  before_action :authenticate_owner!

  private

  def authenticate_owner!
    return if current_owner

    redirect_to admin_login_path, alert: "Faça login para acessar o painel administrativo."
  end

  def current_owner
    @current_owner ||= Owner.find_by(id: session[:owner_id]) if session[:owner_id]
  end
  helper_method :current_owner
end

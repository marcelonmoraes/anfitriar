class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    @host = Host.new
  end

  def create
    @host = Host.new(host_params)
    if @host.save
      Subscription.start_trial_for(@host)
      start_new_session_for @host
      redirect_to root_path,
                  notice: "Bem-vindo ao Anfitriar! Seu período de teste de #{PlatformConfiguration.current.trial_days} dias começou."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def host_params
      params.expect(host: [ :name, :email_address, :phone, :password, :password_confirmation ])
    end
end

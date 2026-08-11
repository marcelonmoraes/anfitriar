class AccountsController < ApplicationController
  def show
    @host = Current.host
    @subscription = @host.subscription
  end

  def update
    @host = Current.host
    if @host.update(host_params)
      redirect_to account_path, notice: "Dados atualizados."
    else
      @subscription = @host.subscription
      render :show, status: :unprocessable_content
    end
  end

  private
    def host_params
      params.expect(host: [ :name, :phone, :email_address, :cpf_cnpj, :postal_code, :address_number ])
    end
end

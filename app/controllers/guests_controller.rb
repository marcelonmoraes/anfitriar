class GuestsController < ApplicationController
  before_action :set_guest, only: %i[edit update destroy]

  def index
    @guests = Current.host.guests.order(:name)
  end

  def new
    @guest = Current.host.guests.build
  end

  def create
    @guest = Current.host.guests.build(guest_params)
    if @guest.save
      redirect_to guests_path, notice: "Cliente cadastrado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @guest.update(guest_params)
      redirect_to guests_path, notice: "Cliente atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @guest.destroy
    redirect_to guests_path, notice: "Cliente excluído. Os dados dele foram removidos."
  end

  private
    def set_guest
      @guest = Current.host.guests.find(params[:id])
    end

    def guest_params
      params.expect(guest: [ :name, :cpf, :phone, :email ])
    end
end

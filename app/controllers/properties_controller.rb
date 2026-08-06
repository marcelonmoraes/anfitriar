class PropertiesController < ApplicationController
  before_action :set_property, only: %i[show edit update destroy]

  def index
    @properties = Current.host.properties.order(:name)
  end

  def show
  end

  def new
    @property = Current.host.properties.build
  end

  def create
    @property = Current.host.properties.build(property_params)
    if @property.save
      redirect_to @property, notice: "Hospedagem criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @property.update(property_params)
      redirect_to @property, notice: "Hospedagem atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @property.destroy
    redirect_to properties_path, notice: "Hospedagem excluída."
  end

  private
    def set_property
      @property = Current.host.properties.find(params[:id])
    end

    def property_params
      params.expect(property: [ :name, :address, :cover_photo ])
    end
end

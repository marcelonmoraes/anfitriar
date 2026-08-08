class Admin::CategoriesController < Admin::ApplicationController
  before_action :set_category, only: %i[show edit update destroy]

  def index
    @categories = Category.standard.order(:position)
  end

  def show
  end

  def new
    @category = Category.new(host: nil)
  end

  def create
    @category = Category.new(category_params.merge(host: nil))
    if @category.save
      redirect_to admin_categories_path, notice: "Categoria padrão criada."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: "Categoria atualizada."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @category.destroy
    redirect_to admin_categories_path, notice: "Categoria excluída."
  end

  private

  def set_category
    @category = Category.standard.find(params[:id])
  end

  def category_params
    params.expect(category: [ :name, :position ])
  end
end
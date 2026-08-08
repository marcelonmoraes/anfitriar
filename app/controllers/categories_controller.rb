class CategoriesController < ApplicationController
  before_action :set_category, only: %i[edit update destroy]

  def index
    @standard_categories = Category.standard.ordered
    @own_categories = Current.host.categories.order(:name)
  end

  def new
    @category = Current.host.categories.build
  end

  def create
    @category = Current.host.categories.build(category_params)
    if @category.save
      redirect_to categories_path, notice: "Categoria criada."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Categoria atualizada."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Categoria excluída."
  end

  private
    def set_category
      @category = Current.host.categories.find(params[:id])
    end

    def category_params
      params.expect(category: [ :name ])
    end
end

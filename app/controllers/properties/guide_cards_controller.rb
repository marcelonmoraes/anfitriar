class Properties::GuideCardsController < ApplicationController
  def update
    property = Current.host.properties.find(params[:property_id])
    category = available_category!(property)

    Card.upsert_for(property, category, card_params)
    redirect_to property_guide_path(property), notice: "Guia atualizado."
  end

  private
    def available_category!(property)
      Category.available_to(property.host).find { |category| category.id == params[:category_id].to_i } ||
        raise(ActiveRecord::RecordNotFound)
    end

    def card_params
      params.expect(card: [ :description, :hidden ])
    end
end

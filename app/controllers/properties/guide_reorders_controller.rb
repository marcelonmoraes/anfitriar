class Properties::GuideReordersController < ApplicationController
  def update
    property = Current.host.properties.find(params[:property_id])
    available = Category.available_to(property.host).index_by(&:id)

    params.expect(category_ids: []).each_with_index do |category_id, index|
      category = available[category_id.to_i] or next
      Card.upsert_for(property, category, position: index + 1)
    end

    head :no_content
  end
end

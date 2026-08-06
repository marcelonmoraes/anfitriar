class Properties::PreviewsController < ApplicationController
  def show
    @property = Current.host.properties.find(params[:property_id])
    @cards = @property.visible_cards
  end
end

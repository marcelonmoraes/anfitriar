class Properties::GuidesController < ApplicationController
  def show
    @property = Current.host.properties.find(params[:property_id])
    @entries = @property.guide_entries
    @progress = @property.guide_progress
  end
end

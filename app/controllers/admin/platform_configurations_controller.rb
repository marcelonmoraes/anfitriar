class Admin::PlatformConfigurationsController < Admin::ApplicationController
  before_action :set_platform_configuration

  def edit
  end

  def update
    if @platform_configuration.update(platform_configuration_params)
      redirect_to edit_admin_platform_configuration_path, notice: "Configurações atualizadas."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_platform_configuration
    @platform_configuration = PlatformConfiguration.current
  end

  def platform_configuration_params
    params.expect(platform_configuration: [ :trial_days, :booking_access_margin_days ])
  end
end
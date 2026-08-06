class PublicGuidesController < ApplicationController
  allow_unauthenticated_access

  # Placeholder do Subprojeto 3: resposta idêntica para qualquer token,
  # sem lookup — nada sobre a reserva pode vazar por aqui.
  def show
  end
end

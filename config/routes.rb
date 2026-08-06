Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]

  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end

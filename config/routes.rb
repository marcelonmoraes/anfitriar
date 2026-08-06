Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :properties
  resources :guests, except: %i[show]

  root "properties#index"

  get "up" => "rails/health#show", as: :rails_health_check
end

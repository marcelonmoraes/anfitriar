Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :properties do
    scope module: :properties do
      resource :guide, only: :show
      patch "guide/cards/:category_id", to: "guide_cards#update", as: :guide_card
      patch "guide/reorder", to: "guide_reorders#update", as: :guide_reorder
    end
  end
  resources :guests, except: %i[show]
  resources :categories, except: %i[show]

  root "properties#index"

  get "up" => "rails/health#show", as: :rails_health_check
end

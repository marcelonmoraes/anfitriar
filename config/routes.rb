Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :properties do
    scope module: :properties do
      resource :guide, only: :show
      patch "guide/cards/:category_id", to: "guide_cards#update", as: :guide_card
      patch "guide/reorder", to: "guide_reorders#update", as: :guide_reorder
      resource :preview, only: :show
    end
  end
  resources :guests, except: %i[show]
  resources :categories, except: %i[show]
  resources :bookings, only: %i[index new create show] do
    member do
      patch :revoke
      patch :reissue
    end
  end

  resource :account, only: %i[show update]

  get "g/:token", to: "public_guides#show", as: :public_guide

  namespace :admin do
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :plans
    resources :categories, except: %i[show]
    resources :hosts, only: %i[index show] do
      resource :subscription, only: %i[new create edit update]
    end
    resource :platform_configuration, only: %i[edit update]

    root to: "dashboard#show"
  end

  root "properties#index"

  get "up" => "rails/health#show", as: :rails_health_check
end

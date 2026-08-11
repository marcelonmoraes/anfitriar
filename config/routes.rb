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

  resource :account, only: %i[show update] do
    resource :subscription, only: %i[show new create edit update destroy]
    resources :credit_cards, only: %i[index create destroy] do
      scope module: :credit_cards do
        resource :default, only: :create
      end
    end
  end

  get "g/:token", to: "public_guides#show", as: :public_guide
  get "g/:token/verify", to: "public_guides#verify", as: :verify_public_guide
  post "g/:token/verify", to: "public_guides#verify_submit", as: :verify_submit_public_guide

  namespace :webhooks do
    resource :asaas, only: :create, controller: :asaas
  end

  namespace :admin do
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :plans
    resources :categories, except: %i[show]
    resources :hosts, only: %i[index show] do
      resource :subscription, only: %i[new create edit update]
    end
    resources :webhook_events, only: [] do
      scope module: :webhook_events do
        resource :reprocessing, only: :create
      end
    end
    resource :platform_configuration, only: %i[edit update]

    root to: "dashboard#show"
  end

  root "properties#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
